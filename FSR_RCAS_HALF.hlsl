// FidelityFX-FSR 中 RCAS 通道
// 移植自 https://github.com/GPUOpen-Effects/FidelityFX-FSR/blob/master/ffx-fsr/ffx_fsr1.h

//!MAGPIE EFFECT
//!VERSION 2
//!OUTPUT_WIDTH INPUT_WIDTH
//!OUTPUT_HEIGHT INPUT_HEIGHT


//!PARAMETER
//!DEFAULT 0.87
//!MIN 1e-5
float sharpness;

//!TEXTURE
Texture2D INPUT;

//!SAMPLER
//!FILTER POINT
SamplerState sam;

//!PASS 1
//!IN INPUT
//!BLOCK_SIZE 16
//!NUM_THREADS 64

#define min3(a, b, c) min(a, min(b, c))
#define max3(a, b, c) max(a, max(b, c))

// This is set at the limit of providing unnatural results for sharpening.
#define FSR_RCAS_LIMIT (0.25-(1.0/16.0))


float3 FsrRcasH(min16float3 b, min16float3 d, min16float3 e, min16float3 f, min16float3 h)
{
	// Rename (32-bit) or regroup (16-bit).
	min16float bR = b.r;
	min16float bG = b.g;
	min16float bB = b.b;
	min16float dR = d.r;
	min16float dG = d.g;
	min16float dB = d.b;
	min16float eR = e.r;
	min16float eG = e.g;
	min16float eB = e.b;
	min16float fR = f.r;
	min16float fG = f.g;
	min16float fB = f.b;
	min16float hR = h.r;
	min16float hG = h.g;
	min16float hB = h.b;

	// Luma times 2.
	min16float bL = bB * min16float(0.5) + (bR * min16float(0.5) + bG);
	min16float dL = dB * min16float(0.5) + (dR * min16float(0.5) + dG);
	min16float eL = eB * min16float(0.5) + (eR * min16float(0.5) + eG);
	min16float fL = fB * min16float(0.5) + (fR * min16float(0.5) + fG);
	min16float hL = hB * min16float(0.5) + (hR * min16float(0.5) + hG);

	// Noise detection.
	min16float nz = min16float(0.25)*bL + min16float(0.25)*dL + min16float(0.25)*fL + min16float(0.25)*hL - eL;
	nz = saturate(abs(nz) * rcp(max3(max3(bL, dL, eL), fL, hL) - min3(min3(bL, dL, eL), fL, hL)));
	nz = min16float(-0.5) * nz + min16float(1.0);

	// Min and max of ring.
	min16float mn4R = min(min3(bR, dR, fR), hR);
	min16float mn4G = min(min3(bG, dG, fG), hG);
	min16float mn4B = min(min3(bB, dB, fB), hB);
	min16float mx4R = max(max3(bR, dR, fR), hR);
	min16float mx4G = max(max3(bG, dG, fG), hG);
	min16float mx4B = max(max3(bB, dB, fB), hB);

	// Immediate constants for peak range.
	min16float2 peakC = min16float2(1.0, -1.0*4.0);

	// Limiters, these need to be high precision RCPs.
	min16float hitMinR = min(mn4R, eR) * rcp(min16float(4.0) * mx4R);
	min16float hitMinG = min(mn4G, eG) * rcp(min16float(4.0) * mx4G);
	min16float hitMinB = min(mn4B, eB) * rcp(min16float(4.0) * mx4B);
	min16float hitMaxR = (peakC.x - max(mx4R, eR)) * rcp(min16float(4.0) * mn4R + peakC.y);
	min16float hitMaxG = (peakC.x - max(mx4G, eG)) * rcp(min16float(4.0) * mn4G + peakC.y);
	min16float hitMaxB = (peakC.x - max(mx4B, eB)) * rcp(min16float(4.0) * mn4B + peakC.y);
	min16float lobeR = max(-hitMinR, hitMaxR);
	min16float lobeG = max(-hitMinG, hitMaxG);
	min16float lobeB = max(-hitMinB, hitMaxB);
	min16float lobe = max(min16float(-FSR_RCAS_LIMIT), min(max3(lobeR, lobeG, lobeB), min16float(0.0))) * min16float(sharpness);

	// Apply noise removal.
	lobe *= nz;

	// Resolve, which needs the medium precision rcp approximation to avoid visible tonality changes.
	min16float rcpL = rcp(min16float(4.0) * lobe + min16float(1.0));
	float3 c = {
		(lobe * bR + lobe * dR + lobe * hR + lobe * fR + eR) * rcpL,
		(lobe * bG + lobe * dG + lobe * hG + lobe * fG + eG) * rcpL,
		(lobe * bB + lobe * dB + lobe * hB + lobe * fB + eB) * rcpL
	};

	return c;
}

void Pass1(uint2 blockStart, uint3 threadId) {
	uint2 gxy = blockStart + (Rmp8x8(threadId.x) << 1);
	if (!CheckViewport(gxy)) {
		return;
	}

	min16float3 src[4][4];
	[unroll]
	for (uint i = 1; i < 3; ++i) {
		[unroll]
		for (uint j = 0; j < 4; ++j) {
			src[i][j] = INPUT.Load(int3(gxy.x + i - 1, gxy.y + j - 1, 0)).rgb;
		}
	}

	src[0][1] = INPUT.Load(int3(gxy.x - 1, gxy.y, 0)).rgb;
	src[0][2] = INPUT.Load(int3(gxy.x - 1, gxy.y + 1, 0)).rgb;
	src[3][1] = INPUT.Load(int3(gxy.x + 2, gxy.y, 0)).rgb;
	src[3][2] = INPUT.Load(int3(gxy.x + 2, gxy.y + 1, 0)).rgb;

	WriteToOutput(gxy, FsrRcasH(src[1][0], src[0][1], src[1][1], src[2][1], src[1][2]));

	++gxy.x;
	if (CheckViewport(gxy)) {
		WriteToOutput(gxy, FsrRcasH(src[2][0], src[1][1], src[2][1], src[3][1], src[2][2]));
	}

	++gxy.y;
	if (CheckViewport(gxy)) {
		WriteToOutput(gxy, FsrRcasH(src[2][1], src[1][2], src[2][2], src[3][2], src[2][3]));
	}

	--gxy.x;
	if (CheckViewport(gxy)) {
		WriteToOutput(gxy, FsrRcasH(src[1][1], src[0][2], src[1][2], src[2][2], src[1][3]));
	}
}
