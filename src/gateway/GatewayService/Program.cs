using System.Collections.Concurrent;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;

using Dapper;

using GatewayService.Services;

using MySqlConnector;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<CytoplasmV4Reader>();

var app = builder.Build();

app.UseWebSockets();

var wsClients = new ConcurrentBag<WebSocket>();

app.MapPost("/api/v1/topology/event", async (TopologyEventRequest request, CytoplasmV4Reader reader, IConfiguration config ) => {
	string dbConnStr = config.GetConnectionString("MariaDB")
	?? "Server=localhost;Database=revelatio_db;Uid=root;Pwd=password;";

	var triggerPosts = reader.ReadTopTriggerPosts();

	long spectrumId = 0;
	
	await using (var conn = new MySqlConnection(dbConnStr)) {
		await conn.OpenAsync();
		await using var tx = await conn.BeginTransactionAsync();

		try {
			const string sqlSpectrum = @"
				INSERT INTO spectrum_history_v2
				(calculated_at_ns, re_lambda_max, mean_ricci_curvature, tda_h1_persistence, tda_h2_persistence, sindy_residual, state_flags)
				VALUES (@CalculatedAtNs, @ReLambdaMax, @MeanRicciCurvature, @TdaH1Persistence, @TdaH2Persistence, @SindyResidual, @StateFlags);
				SELECT LAST_INSERT_ID()";

			spectrumId = await conn.ExecuteScalarAsync<long>(sqlSpectrum, new {
				CalculatedAtNs = request.CalculatedAtNs,
				ReLambdaMax = request.ReLambdaMax,
				MeanRicciCurvature = request.MeanRicciCurvature,
				TdaH1Persistence = request.TdaH1Persistence,
				TdaH2Persistence = request.TdaH2Persistence,
				SindyResidual = request.SindyResidual,
				StateFlags = request.StateFlags
			}, tx);

			if (triggerPosts.Count > 0) {
				const string sqlPosts = @"
					INSERT INTO critical_trigger_posts_v2
					(spectrum_id, slot_index, post_uri, author_did, post_text, contribution_score, local_ricci_curvature, structural_role)
					VALUES (@SpectrumId, @SlotIndex, @Uri, @AuthorDid, @Text, @ContributionScore, @LocalRicciCurvature, @StructuralRole);";

				var postEntities = triggerPosts.Select(p => new {
					SpectrumId = spectrumId,
					SlotIndex = p.SlotIndex,
					Uri = p.Uri,
					AuthorDid = p.AuthorDid,
					Text = p.Text,
					ContributionScore = p.ContributionScore,
					LocalRicciCurvature = p.LocalRicciCurvature,
					StructuralRole = p.StructuralRole
				});

				await conn.ExecuteAsync(sqlPosts, postEntities, tx);
			}

			await tx.CommitAsync();
		} catch (Exception ex) {
			await tx.RollbackAsync();
			Console.WriteLine($"[DB Error Transaction failed: {ex.Message}");
			return Results.Problem("Database persistence failed.", statusCode: 500);
		}
	}

	var payload = JsonSerializer.Serialize(new {
		spectrumId,
		metrics = request,
		triggerPosts
	});

	byte[] bytes = Encoding.UTF8.GetBytes(payload);
	var deadSockets = new List<WebSocket>();

	foreach (var socket in wsClients) {
		if (socket.State == WebSocketState.Open) {
			_ = socket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
		} else {
			deadSockets.Add(socket);
		}
	}

	foreach (var dead in deadSockets) {
		wsClients.TryTake(out _);
	}

	return Results.Ok(new { status = "ACCEPTED", spectrumId, particleCount = triggerPosts.Count });
});

app.Map("/ws/topology", async (HttpContext context) => {
	if (context.WebSockets.IsWebSocketRequest) {
		using var webSocket = await context.WebSockets.AcceptWebSocketAsync();
		wsClients.Add(webSocket);
		Console.WriteLine($"[WebSocket] Client connected. Total active: {wsClients.Count}");
		
		var buffer = new byte[1024];
		while (webSocket.State == WebSocketState.Open) {
			var result = await webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), CancellationToken.None);
			if (result.MessageType == WebSocketMessageType.Close) {
				break;
			}
		}

		wsClients.TryTake(out _);
		Console.WriteLine("[WebSocket] Client disconnected.");
	} else {
		context.Response.StatusCode = StatusCodes.Status400BadRequest;
	}
});

app.Run();

public record TopologyEventRequest (
	long CalculatedAtNs,
	double ReLambdaMax,
	double MeanRicciCurvature,
	double TdaH1Persistence,
	double TdaH2Persistence,
	double SindyResidual,
	uint StateFlags
);



