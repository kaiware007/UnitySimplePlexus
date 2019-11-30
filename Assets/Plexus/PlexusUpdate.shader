Shader "Kaiware007/Plexus Update"
{
	Properties
	{
		_PositionSpeed1("Position Noise Speed 1", float) = 0.1
		_PositionSpeed2("Position Noise Speed 2", float) = 0.1
		_PositionRange("Position Range", Vector) = (1,1,1,0)
		_PositionNoiseScale("Position Noise Scale", vector) = (1,1,1,0)		
	}

	CGINCLUDE

	#include "UnityCustomRenderTexture.cginc"
	#include "Noise.cginc"

	float _PositionSpeed1;
	float _PositionSpeed2;
	float3 _PositionRange;
	float3 _PositionNoiseScale;

	float4 fragUpdatePosition(v2f_customrendertexture i) : SV_Target
	{
		// テクスチャのUV座標（3次元）
		float3 pos = i.globalTexcoord;
		
		// 1ドット = 1メートルとする
		pos *= float3(_CustomRenderTextureWidth, _CustomRenderTextureHeight, _CustomRenderTextureDepth);

		// 時間の計算
		// RTX2080系だとノイズ関数で浮動小数点演算の誤差かなんかで結果が偏りまくるのであまり大きな値にならないようにしている（ループするときに微妙だけど…）
		float time = fmod(_Time.y, 256) + 138.21;

		// シンプレックスノイズで座標をゆらゆらさせてる
		float noiseSpeed = snoise(float2(pos.x + pos.y * _CustomRenderTextureWidth + pos.z * _CustomRenderTextureWidth * _CustomRenderTextureHeight / 34.2148, time * _PositionSpeed1 + 32.153));
		float yz = time * noiseSpeed * _PositionSpeed2;
		pos.xyz += snoise3D(pos.xyz  * _PositionNoiseScale + float3(yz * 0.1, yz * 0.34, yz * 0.75)) * _PositionRange;
		pos /= float3(_CustomRenderTextureWidth, _CustomRenderTextureHeight, _CustomRenderTextureDepth); // 正規化

		// テクスチャに座標を書き込む
		return float4(pos, 1);
	}
	ENDCG

	SubShader
	{
		Cull Off ZWrite Off ZTest Always
			
		Pass
		{
			Name "UpdatePosition"
			CGPROGRAM
			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment fragUpdatePosition
			ENDCG
		}
	}
}
