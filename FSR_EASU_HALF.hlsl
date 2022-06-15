// FidelityFX-FSR 中 EASU 通道
// 移植自 https://github.com/GPUOpen-Effects/FidelityFX-FSR/blob/master/ffx-fsr/ffx_fsr1.h

//!MAGPIE EFFECT
//!VERSION 2

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


void FsrEasuTapH(
 	inout min16float2 aCR,
	inout min16float2 aCG,
	inout min16float2 aCB,
	inout min16float2 aW,
	min16float2 offX,
	min16float2 offY,
	min16float2 dir,
	min16float2 len,
	min16float lob,
	min16float clp,
	min16float2 cR,
	min16float2 cG,
	min16float2 cB)
{
	min16float2 vX, vY;
	vX = offX*dir.xx + offY*dir.yy;
	vY = offX*(-dir.yy) + offY*dir.xx;
	vX *= len.x;
	vY *= len.y;

	min16float2 d2 = vX*vX + vY*vY;
	d2 = min(d2, min16float2(clp, clp));

	min16float2 wB = min16float2(2.0/5.0, 2.0/5.0)*d2 + min16float2(-1.0, -1.0);
	min16float2 wA = min16float2(lob, lob)*d2 + min16float2(-1.0, -1.0);
	wB *= wB;
	wA *= wA;
		
	wB = min16float2(25.0/16.0, 25.0/16.0)*wB + min16float2(-(25.0/16.0-1.0), -(25.0/16.0-1.0));

	min16float2 w = wB * wA;
	aCR += cR * w;
	aCG += cG * w;
	aCB += cB * w;
	aW += w;
}

void FsrEasuSetH(
	inout min16float2 dirPX,
	inout min16float2 dirPY,
	inout min16float2 lenP,
	min16float2 pp,
	bool biST,
	bool biUV,
	min16float2 lA,
	min16float2 lB,
	min16float2 lC,
	min16float2 lD,
	min16float2 lE)
{
 	min16float2 w = min16float2(0.0, 0.0);

	if (biST)
		w = (min16float2(1.0, 0.0) + min16float2(-pp.x, pp.x)) * min16float2(min16float(1.0)-pp.y, min16float(1.0)-pp.y);
	
	if (biUV)
		w = (min16float2(1.0, 0.0) + min16float2(-pp.x, pp.x)) * min16float2(pp.y, pp.y);

	// ABS is not free in the packed FP16 path.
	min16float2 dc = lD - lC;
	min16float2 cb = lC - lB;
	min16float2 lenX = max(abs(dc), abs(cb));
	lenX = rcp(lenX);

	min16float2 dirX = lD - lB;
	dirPX += dirX * w;
	lenX = saturate(abs(dirX) * lenX);
	lenX *= lenX;
	lenP += lenX * w;
	
	min16float2 ec = lE - lC;
	min16float2 ca = lC - lA;
	min16float2 lenY = max(abs(ec), abs(ca));
	lenY = rcp(lenY);
	
	min16float2 dirY = lE - lA;
	dirPY += dirY * w;
	lenY = saturate(abs(dirY) * lenY);
	lenY *= lenY;
	lenP += lenY * w;
}

float3 FsrEasuH(uint2 pos, float4 con0, float4 con1, float4 con2, float2 con3)
{
//------------------------------------------------------------------------------------------------------------------------------
	float2 pp = float2(pos) * con0.xy + con0.zw;
	float2 fp = floor(pp);
	pp -= fp;
	min16float2 ppp = min16float2(pp);

//------------------------------------------------------------------------------------------------------------------------------
	float2 p0 = fp * con1.xy + con1.zw;
	float2 p1 = p0 + con2.xy;
	float2 p2 = p0 + con2.zw;
	float2 p3 = p0 + con3;
	min16float4 bczzR = INPUT.GatherRed(sam, p0);
	min16float4 bczzG = INPUT.GatherGreen(sam, p0);
	min16float4 bczzB = INPUT.GatherBlue(sam, p0);
	min16float4 ijfeR = INPUT.GatherRed(sam, p1);
	min16float4 ijfeG = INPUT.GatherGreen(sam, p1);
	min16float4 ijfeB = INPUT.GatherBlue(sam, p1);
	min16float4 klhgR = INPUT.GatherRed(sam, p2);
	min16float4 klhgG = INPUT.GatherGreen(sam, p2);
	min16float4 klhgB = INPUT.GatherBlue(sam, p2);
	min16float4 zzonR = INPUT.GatherRed(sam, p3);
	min16float4 zzonG = INPUT.GatherGreen(sam, p3);
	min16float4 zzonB = INPUT.GatherBlue(sam, p3);

//------------------------------------------------------------------------------------------------------------------------------
	min16float4 bczzL = bczzB * min16float(0.5) + (bczzR * min16float(0.5) + bczzG);
	min16float4 ijfeL = ijfeB * min16float(0.5) + (ijfeR * min16float(0.5) + ijfeG);
	min16float4 klhgL = klhgB * min16float(0.5) + (klhgR * min16float(0.5) + klhgG);
	min16float4 zzonL = zzonB * min16float(0.5) + (zzonR * min16float(0.5) + zzonG);
	min16float bL = bczzL.x;
	min16float cL = bczzL.y;
	min16float iL = ijfeL.x;
	min16float jL = ijfeL.y;
	min16float fL = ijfeL.z;
	min16float eL = ijfeL.w;
	min16float kL = klhgL.x;
	min16float lL = klhgL.y;
	min16float hL = klhgL.z;
	min16float gL = klhgL.w;
	min16float oL = zzonL.z;
	min16float nL = zzonL.w;

	// This part is different, accumulating 2 taps in parallel.
	min16float2 dirPX = min16float2(0.0, 0.0);
	min16float2 dirPY = min16float2(0.0, 0.0);
	min16float2 lenP = min16float2(0.0, 0.0);
	FsrEasuSetH(dirPX, dirPY, lenP, ppp, true, false, min16float2(bL, cL), min16float2(eL, fL), min16float2(fL, gL), min16float2(gL, hL), min16float2(jL, kL));
	FsrEasuSetH(dirPX, dirPY, lenP, ppp, false, true, min16float2(fL, gL), min16float2(iL, jL), min16float2(jL, kL), min16float2(kL, lL), min16float2(nL, oL));
	min16float2 dir = min16float2(dirPX.r + dirPX.g, dirPY.r + dirPY.g);
	min16float len = lenP.r + lenP.g;

//------------------------------------------------------------------------------------------------------------------------------
	min16float2 dir2 = dir * dir;
	min16float dirR = dir2.x + dir2.y;
	bool zro = dirR < min16float(1.0 / 32768.0);

	dirR = rsqrt(dirR);
	dirR = zro? min16float(1.0): dirR;
	dir.x = zro? min16float(1.0): dir.x;
	dir *= min16float2(dirR, dirR);
	len = len * min16float(0.5);
	len *= len;
	min16float stretch = (dir.x*dir.x + dir.y*dir.y) * rcp(max(abs(dir.x), abs(dir.y)));
	min16float2 len2 = min16float2(min16float(1.0) + (stretch-min16float(1.0))*len, min16float(1.0)+min16float(-0.5)*len);
	min16float lob = min16float(0.5) + min16float((1.0/4.0-0.04)-0.5) * len;
	min16float clp = rcp(lob);

//------------------------------------------------------------------------------------------------------------------------------
	// FP16 is different, using packed trick to do min and max in same operation.
	min16float2 bothR = max(max(min16float2(-ijfeR.z, ijfeR.z), min16float2(-klhgR.w, klhgR.w)), max(min16float2(-ijfeR.y, ijfeR.y), min16float2(-klhgR.x, klhgR.x)));
	min16float2 bothG = max(max(min16float2(-ijfeG.z, ijfeG.z), min16float2(-klhgG.w, klhgG.w)), max(min16float2(-ijfeG.y, ijfeG.y), min16float2(-klhgG.x, klhgG.x)));
	min16float2 bothB = max(max(min16float2(-ijfeB.z, ijfeB.z), min16float2(-klhgB.w, klhgB.w)), max(min16float2(-ijfeB.y, ijfeB.y), min16float2(-klhgB.x, klhgB.x)));
	
	// This part is different for FP16, working pairs of taps at a time.
	min16float2 pR = min16float2(0.0, 0.0);
	min16float2 pG = min16float2(0.0, 0.0);
	min16float2 pB = min16float2(0.0, 0.0);
	min16float2 pW = min16float2(0.0, 0.0);

	FsrEasuTapH(pR, pG, pB, pW, min16float2( 0.0, 1.0)-ppp.xx, min16float2(-1.0, -1.0)-ppp.yy, dir, len2, lob, clp, bczzR.xy, bczzG.xy, bczzB.xy);
	FsrEasuTapH(pR, pG, pB, pW, min16float2(-1.0, 0.0)-ppp.xx, min16float2( 1.0,  1.0)-ppp.yy, dir, len2, lob, clp, ijfeR.xy, ijfeG.xy, ijfeB.xy);
	FsrEasuTapH(pR, pG, pB, pW, min16float2( 0.0,-1.0)-ppp.xx, min16float2( 0.0,  0.0)-ppp.yy, dir, len2, lob, clp, ijfeR.zw, ijfeG.zw, ijfeB.zw);
	FsrEasuTapH(pR, pG, pB, pW, min16float2( 1.0, 2.0)-ppp.xx, min16float2( 1.0,  1.0)-ppp.yy, dir, len2, lob, clp, klhgR.xy, klhgG.xy, klhgB.xy);
	FsrEasuTapH(pR, pG, pB, pW, min16float2( 2.0, 1.0)-ppp.xx, min16float2( 0.0,  0.0)-ppp.yy, dir, len2, lob, clp, klhgR.zw, klhgG.zw, klhgB.zw);
	FsrEasuTapH(pR, pG, pB, pW, min16float2( 1.0, 0.0)-ppp.xx, min16float2( 2.0,  2.0)-ppp.yy, dir, len2, lob, clp, zzonR.zw, zzonG.zw, zzonB.zw);
	min16float3 aC = min16float3(pR.x+pR.y, pG.x+pG.y, pB.x+pB.y);
	min16float aW = pW.x + pW.y;

//------------------------------------------------------------------------------------------------------------------------------
	// Slightly different for FP16 version due to combined min and max.
	min16float rcpaW = rcp(aW);
	min16float3 pix = min(min16float3(bothR.y, bothG.y, bothB.y), max(-min16float3(bothR.x, bothG.x, bothB.x), aC*min16float3(rcpaW, rcpaW, rcpaW)));

	return float3(pix);
}

void Pass1(uint2 blockStart, uint3 threadId) {
	uint2 gxy = blockStart + Rmp8x8(threadId.x);
	if (!CheckViewport(gxy)) {
		return;
	}

	uint2 inputSize = GetInputSize();
	uint2 outputSize = GetOutputSize();
	float2 inputPt = GetInputPt();

	float4 con0, con1, con2;
	float2 con3;
	// Output integer position to a pixel position in viewport.
	con0[0] = (float)inputSize.x / (float)outputSize.x;
	con0[1] = (float)inputSize.y / (float)outputSize.y;
	con0[2] = 0.5f * con0[0] - 0.5f;
	con0[3] = 0.5f * con0[1] - 0.5f;
	// Viewport pixel position to normalized image space.
	// This is used to get upper-left of 'F' tap.
	con1[0] = inputPt.x;
	con1[1] = inputPt.y;
	// Centers of gather4, first offset from upper-left of 'F'.
	//      +---+---+
	//      |   |   |
	//      +--(0)--+
	//      | b | c |
	//  +---F---+---+---+
	//  | e | f | g | h |
	//  +--(1)--+--(2)--+
	//  | i | j | k | l |
	//  +---+---+---+---+
	//      | n | o |
	//      +--(3)--+
	//      |   |   |
	//      +---+---+
	con1[2] = inputPt.x;
	con1[3] = -inputPt.y;
	// These are from (0) instead of 'F'.
	con2[0] = -inputPt.x;
	con2[1] = 2.0f * inputPt.y;
	con2[2] = inputPt.x;
	con2[3] = 2.0f * inputPt.y;
	con3[0] = 0;
	con3[1] = 4.0f * inputPt.y;

	WriteToOutput(gxy, FsrEasuH(gxy, con0, con1, con2, con3));

	gxy.x += 8u;
	if (CheckViewport(gxy)) {
		WriteToOutput(gxy, FsrEasuH(gxy, con0, con1, con2, con3));
	}

	gxy.y += 8u;
	if (CheckViewport(gxy)) {
		WriteToOutput(gxy, FsrEasuH(gxy, con0, con1, con2, con3));
	}

	gxy.x -= 8u;
	if (CheckViewport(gxy)) {
		WriteToOutput(gxy, FsrEasuH(gxy, con0, con1, con2, con3));
	}
}

