using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace GatewayService.Services;

[StructLayout(LayoutKind.Sequential, Pack = 1)]
public unsafe struct TriggerParticle {
	public uint SlotId;
	public uint StructuralRole;
	public double AttributionScore;
	public double LocalRicciCurvature;
}

[StructLayout(LayoutKind.Sequential, Pack = 1)]
public unsafe struct ParticleOutputArea {
	public uint TriggerCount;
	public fixed byte ParticlesRaw[64 * 24];
	public ulong CalculatedAtNs;
	public fixed byte Reserved[128];
}

public record TriggerPostDto (
	uint SlotIndex,
	string Uri,
	string AuthorDid,
	string Text,
	double ContributionScore,
	double LocalRicciCurvature,
	string StructuralRole
);

public unsafe class CytoplasmV4Reader : IDisposable {
	private const int CYTOPLASM_V4_IPC_KEY = 0x41504550;
	private const int TEXT_URI_MAX_LEN = 256;
	private const int TEXT_AUTHOR_MAX_LEN = 128;
	private const int TEXT_BODY_MAX_LEN = 2048;
	private const int TEXT_SLOT_SIZE = 20480;

	private const int PARTICLE_OUTPUT_OFFSET = 0x0DC0;
	private const long TEXT_LRU_OFFSET = 0x0C044000;
	private const uint TEXT_LRU_CAPACITY = 16384;

	[DllImport("libc", SetLastError = true)]
	private static extern int shmget(int key, nuint size, int shmflg);

	[DllImport("libc", SetLastError = true)]
	private static extern void* shmat(int shmid, void* shmaddr, int shmflg);

	[DllImport("libc", SetLastError = true)]
	private static extern int shmdt(void* shmaddr);

	private readonly void* _shmPtr;

	public CytoplasmV4Reader() {
		int shmId = shmget(CYTOPLASM_V4_IPC_KEY, 0, 0);
		if (shmId < 0) {
			Console.WriteLine("[Gateway Warning] Cytoplasm IV SHM (0x41504550) not found. Ingester required.");
			_shmPtr = null;
			return;
		}

		_shmPtr = shmat(shmId, null, 0);
		if (_shmPtr == (void*)-1) {
			Console.WriteLine("[Gateway Error] Failed to attach Shared Memory.");
			_shmPtr = null;
		} else {
			Console.WriteLine("[Gateway Service] Attached to Cytoplasm IV Shared Memory (512MB).");
		}
	}

	public List<TriggerPostDto> ReadTopTriggerPosts() {
		var posts = new List<TriggerPostDto>();
		if (_shmPtr == null) {
			return posts;
		}

		byte* basePtr = (byte*)_shmPtr;
		ParticleOutputArea* particleArea = (ParticleOutputArea*)(basePtr + PARTICLE_OUTPUT_OFFSET);

		uint count = Math.Min(particleArea->TriggerCount, 64U);
		if (count == 0) {
			return posts;
		}

		byte* textLruBase = basePtr + TEXT_LRU_OFFSET;
		TriggerParticle* particles = (TriggerParticle*)particleArea->ParticlesRaw;

		for (int i = 0; i < count; i++) {
			uint slotIdx = particles[i].SlotId % TEXT_LRU_CAPACITY;
			byte* slotPtr = textLruBase + (slotIdx * TEXT_SLOT_SIZE);

			string uri = ReadUtf8String(slotPtr + 16, TEXT_URI_MAX_LEN);
			string author = ReadUtf8String(slotPtr + 16 + TEXT_URI_MAX_LEN, TEXT_AUTHOR_MAX_LEN);
			string text = ReadUtf8String(slotPtr + 16 + TEXT_URI_MAX_LEN + TEXT_AUTHOR_MAX_LEN, TEXT_BODY_MAX_LEN);
			
			if (string.IsNullOrWhiteSpace(author) && string.IsNullOrWhiteSpace(text)) {
				continue;
			}

			string roleStr = (particles[i].StructuralRole) switch {
				0x01 => "SINGULARITY_CATALYST",
				0x02 => "BOUNDARY_BREAKER",
				0x04 => "VORTICITY_CENTER",
				_ => "SINGULARITY_CATALYST"
			};

			posts.Add(new TriggerPostDto (
				slotIdx,
				uri,
				author,
				text,
				particles[i].AttributionScore,
				particles[i].LocalRicciCurvature,
				roleStr
			));
		}
		return posts;
	}

	private static string ReadUtf8String(byte* ptr, int maxLen) {
		int len = 0;
		while (len < maxLen && ptr[len] != 0) {
			len++;
		}

		if (len == 0) {
			return string.Empty;
		}

		return Encoding.UTF8.GetString(ptr, len).TrimEnd('\0', ' ', '\r', '\n', '\t');
	}

	public void Dispose() {
		if (_shmPtr != null && _shmPtr != (void*)-1) {
			shmdt(_shmPtr);
		}
	}
}






