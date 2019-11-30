Shader "Kaiware007/Plexus Draw"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "black" {}
		_PosTex3D ("Position Texture", 3D) = "black" {}
		_PosTexTexelSize ("Position Texture TexelSize", vector) = (1,1,1,1)
		_Size("Particle Size", float) = 0.01
		_SizeNoiseScale("Particle Size Noise Scale", float) = 0.05
		_SizeNoiseSpeed("Particle Size Noise Speed", float) = 1.0
		
		_LineWidth("Line Width", Range(0,1)) = 1 
		_Intensity("Intensity", float) = 1.1
		_FogPower("Fog Power", float) = 1

		_Color("Color", Color) = (1,1,1,1)
		_ColorNoiseScale("Color Noise Scale", vector) = (1,1,1,1)
		_ColorNoiseSpeed("Color Noise Speed", float) = 1
		_ColorSat("Color Saturate", Range(0,1)) = 0.8 

		_ConectDist("Connect Distance", float) = 0.5
	}
	SubShader
	{
		Tags {"Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent"}
		LOD 100

		Blend One One
		ZWrite Off
		Cull Off

		CGINCLUDE

		#include "UnityCG.cginc"
		#include "Noise.cginc"

		struct appdata
		{
			float4 vertex : POSITION;
			uint vid : SV_VertexID;
		};

		struct v2g
		{
			float4 vertex : SV_POSITION;
			uint vid : TEXCOORD0;
			float scale : TEXCOORD1;
			float particleIntensity : TEXCOORD2;
			float lineIntensity : TEXCOORD3;
			float4 positions[7] : TEXCOORD4;
		};

		struct g2f
		{
			float4 pos : SV_POSITION;
			float2 uv : TEXCOORD0;
			float intensity : TEXCOORD1;
			float3 color : TEXCOORD2;
		};

		float3 hsv2rgb(float3 c)
		{
			float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
			float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
			return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
		}

		sampler2D _MainTex;
		float4 _MainTex_ST;
		UNITY_DECLARE_TEX3D(_PosTex3D);
		float3 _PosTexTexelSize;

		float _Size;
		float _SizeNoiseScale;
		float _SizeNoiseSpeed;
		float _LineWidth;
		float _Intensity;
		float _FogPower;

		float4 _Color;
		float3 _ColorNoiseScale;
		float _ColorNoiseSpeed;
		float _ColorSat;

		float _ConectDist;


		v2g vert(appdata v)
		{
			v2g o;

			float3 vpos = v.vertex.xyz + _PosTexTexelSize.xyz * 0.5; // 自身のUV座標

			// 3次元テクスチャから頂点座標を取り出す
			float4 pos = UNITY_SAMPLE_TEX3D_LOD(_PosTex3D, vpos, 0);

			float time = fmod(_Time.y, 256) + 132.5347;
			
			// 自身の頂点座標をワールド座標に変換
			o.vertex = mul(unity_ObjectToWorld, pos);
			
			o.vid = v.vid;
			o.scale = clamp((_Size + (snoise(float2((float)v.vid / 234.2148, time * _SizeNoiseSpeed + 32.153)) * 0.5 + 0.5) *_SizeNoiseScale), 0.01, 1);

			// パーティクルや線のの明るさ計算
			o.particleIntensity = saturate(exp(-distance(o.vertex.xyz, _WorldSpaceCameraPos.xyz) * _FogPower));
			o.lineIntensity = saturate(o.particleIntensity);

			// 隣接する頂点の座標を取得
			float4 pos0 = UNITY_SAMPLE_TEX3D_LOD(_PosTex3D, vpos + float3(0, 0, _PosTexTexelSize.z), 0);
			float4 pos1 = UNITY_SAMPLE_TEX3D_LOD(_PosTex3D, vpos + float3(_PosTexTexelSize.x, 0, _PosTexTexelSize.z), 0);
			float4 pos2 = UNITY_SAMPLE_TEX3D_LOD(_PosTex3D, vpos + float3(_PosTexTexelSize.x, 0, 0), 0);
			float4 pos3 = UNITY_SAMPLE_TEX3D_LOD(_PosTex3D, vpos + float3(0, _PosTexTexelSize.y, 0), 0);
			float4 pos4 = UNITY_SAMPLE_TEX3D_LOD(_PosTex3D, vpos + float3(0, _PosTexTexelSize.yz), 0);
			float4 pos5 = UNITY_SAMPLE_TEX3D_LOD(_PosTex3D, vpos + float3(_PosTexTexelSize.xyz), 0);
			float4 pos6 = UNITY_SAMPLE_TEX3D_LOD(_PosTex3D, vpos + float3(_PosTexTexelSize.xy, 0), 0);

			// ワールド座標に変換
			o.positions[0] = mul(unity_ObjectToWorld, pos0);
			o.positions[1] = mul(unity_ObjectToWorld, pos1);
			o.positions[2] = mul(unity_ObjectToWorld, pos2);
			o.positions[3] = mul(unity_ObjectToWorld, pos3);
			o.positions[4] = mul(unity_ObjectToWorld, pos4);
			o.positions[5] = mul(unity_ObjectToWorld, pos5);
			o.positions[6] = mul(unity_ObjectToWorld, pos6);
			return o;
		}

		// ジオメトリシェーダ
		[maxvertexcount(46)]
		void geom(point v2g input[1], inout TriangleStream<g2f> outStream)
		{
			g2f output;
			float4 pos = input[0].vertex;
			float particleIntensity = input[0].particleIntensity;
			float lineIntensity = input[0].lineIntensity;
			float scale = input[0].scale;
			float3 color = hsv2rgb(float3(snoise(float4(pos.xyz * _ColorNoiseScale, _Time.y * _ColorNoiseSpeed)) * 0.5 + 0.5, _ColorSat, 1));

			// ビルボード用の行列
			float4x4 billboardMatrix = UNITY_MATRIX_V;
			billboardMatrix._m03 = billboardMatrix._m13 = billboardMatrix._m23 = billboardMatrix._m33 = 0;

			// パーティクル（点）の板ポリ作成
			// 四角形になるように頂点を生産
			for (int x = 0; x < 2; x++)
			{
				for (int y = 0; y < 2; y++)
				{
					// UV
					float2 uv = float2(x * 0.5, y);
					output.uv = uv;

					// 頂点位置を計算
					output.pos = pos + mul(float4((float2(x, y) * 2 - float2(1, 1)) * scale, 0, 1), billboardMatrix);
					output.pos = mul(UNITY_MATRIX_VP, output.pos);
					output.intensity = particleIntensity;
					output.color = color;

					// ストリームに頂点を追加
					outStream.Append(output);
				}
			}

			// トライアングルストリップを終了
			outStream.RestartStrip();

			// 線の処理
			if (lineIntensity > 0.0) {
				// 近い点同士を線で結ぶ
				float cameraDiff = pos.xyz - _WorldSpaceCameraPos;
				float3 normal = normalize(cameraDiff);

				for (int i = 0; i < 7; i++)
				{
					float4 targetPos = input[0].positions[i];

					// 点同士の距離を判定
					float len = distance(targetPos, pos);
					if (len <= _ConectDist)
					{
						float3 dir = normalize(targetPos.xyz - pos.xyz);
						float3 right = normalize(cross(dir, normal)) * _LineWidth * 0.5;

						float4 v0 = mul(UNITY_MATRIX_VP, float4(pos.xyz - right, 1));
						float4 v1 = mul(UNITY_MATRIX_VP, float4(pos.xyz + right, 1));
						float4 v2 = mul(UNITY_MATRIX_VP, float4(targetPos.xyz - right, 1));
						float4 v3 = mul(UNITY_MATRIX_VP, float4(targetPos.xyz + right, 1));

						float3 targetColor = hsv2rgb(float3(snoise(float4(targetPos.xyz * _ColorNoiseScale, _Time.y * _ColorNoiseSpeed)) * 0.5 + 0.5, _ColorSat, 1));

						// 点同士の距離に応じて線の明るさを変える（近いほど明るい）
						float distIntensity = 1 - smoothstep(0.0, 0.5, saturate(len / _ConectDist));
						output.intensity = lineIntensity * distIntensity;

						// 線が見える時にだけ線を引く
						if (output.intensity > 0.0)
						{
							// triangle line
							output.pos = v0;
							output.uv = float2(0.5, 0);
							output.color = color;
							outStream.Append(output);

							output.pos = v2;
							output.uv = float2(0.5, 1);
							output.color = targetColor;
							outStream.Append(output);

							output.pos = v1;
							output.uv = float2(1, 0);
							output.color = color;
							outStream.Append(output);

							outStream.RestartStrip();

							output.pos = v2;
							output.uv = float2(0.5, 1);
							output.color = targetColor;
							outStream.Append(output);

							output.pos = v3;
							output.uv = float2(1, 1);
							output.color = targetColor;
							outStream.Append(output);

							output.pos = v1;
							output.uv = float2(1, 0);
							output.color = color;
							outStream.Append(output);

							outStream.RestartStrip();
						}
					}
				}
			}
		}

		fixed4 frag(g2f i) : SV_Target
		{
			// sample the texture
			fixed4 col = tex2D(_MainTex, i.uv);
			col.rgb *= _Intensity * i.intensity * i.color;

			return col;
		}
		ENDCG

		// パーティクル＆ライン
		Pass
		{
			CGPROGRAM
			#pragma target 5.0

			#pragma vertex vert
			#pragma fragment frag
			#pragma geometry geom

			ENDCG
		}
	}
}
