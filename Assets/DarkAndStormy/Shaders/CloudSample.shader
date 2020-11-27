Shader "Skybox/CloudSample"
{
	Properties
	{
		_Cube ("Environment Map (RGB)", CUBE) = "" {}
		_Rotation ("Rotation", Vector) = (0, 0, 0, 0)
		_RotationSpeed("Rotation Speed", float) = 1

		[NoScaleOffset] _CloudTex1 ("Clouds 1", 2D) = "white" {}
		_Tiling1("Tiling 1", Vector) = (1,1,0,0)

		[NoScaleOffset] _WaveTex ("Wave", 2D) = "white" {}
		_TilingWave("Tiling Wave", Vector) = (1,1,0,0)
		_WaveAmount ("Wave Amount", float) = 0.5
		_WaveDistort ("Wave Distort", float) = 0.05

		_CloudScale ("Clouds Scale", float) = 1.0
		_CloudBias ("Clouds Bias", float) = 0.0

		[NoScaleOffset] _ColorTex ("Color Tex", 2D) = "white" {}
		_TilingColor("Tiling Color", Vector) = (1,1,0,0)
		_ColPow ("Color Power", float) = 1
		_ColFactor ("Color Factor", float) = 1

		_Color ("Color", Color) = (1.0,1.0,1.0,1)
		_Color2 ("Color2", Color) = (1.0,1.0,1.0,1)

		_CloudDensity ("Cloud Density", float) = 5.0

		_BumpOffset ("BumpOffset", float) = 0.1
		_Steps ("Steps", float) = 10

		_CloudHeight ("Cloud Height", float) = 100
		_Scale ("Scale", float) = 10

		_Speed ("Speed", float) = 1
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#define SKYBOX

			#include "UnityCG.cginc"
			#include "FogInclude.cginc"

			samplerCUBE _Cube;   
			float4 _Rotation;
			float _RotationSpeed;

			sampler2D _CloudTex1;
			sampler2D _WaveTex;

			float4 _Tiling1;
			float4 _Tiling2;
			float4 _TilingWave;

			float _CloudScale;
			float _CloudBias;

			float _Cloud2Amount;
			float _WaveAmount;
			float _WaveDistort;

			sampler2D _ColorTex;
			float4 _TilingColor;

			float4 _Color;
			float4 _Color2;

			float _CloudDensity;

			float _BumpOffset;
			float _Steps;

			float _CloudHeight;
			float _Scale;
			float _Speed;

			float _ColPow;
			float _ColFactor;

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 texcoord : TEXCOORD0;
				float3 worldPos : TEXCOORD1; 
			};

			float rand3( float3 co ){
			    return frac( sin( dot( co.xyz ,float3(17.2486,32.76149, 368.71564) ) ) * 32168.47512);
			}

			float4x4 Rotate(float4 rotation) {
                float4 rad = radians(rotation);
                float4 sinRad,cosRad;
				sincos(rad, sinRad, cosRad);

                float4x4 mat = float4x4(cosRad.y * cosRad.z, -cosRad.y * sinRad.z, sinRad.y, 0,
                                        cosRad.x * sinRad.z + sinRad.x * sinRad.y * cosRad.z, cosRad.x * cosRad.z - sinRad.x * sinRad.y * sinRad.z, -sinRad.x * cosRad.y, 0,
                                        sinRad.x * sinRad.z - cosRad.x * sinRad.y * cosRad.z, sinRad.x * cosRad.z + cosRad.x * sinRad.y * sinRad.z, (cosRad.x * cosRad.y), 0,
                                        0, 0, 0, 1);

                return mat;
            }
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				float4x4 rotMat = Rotate(_Rotation * _RotationSpeed * _Time.y);
				o.texcoord = mul(rotMat, v.texcoord);
				o.worldPos = mul( unity_ObjectToWorld, v.vertex ).xyz;
				return o;
			}

			fixed4 frag (v2f IN) : SV_Target
			{
				float4 environment = texCUBE(_Cube, IN.texcoord);

				// generate a view direction fromt he world position of the skybox mesh
				float3 viewDir = normalize( IN.worldPos - _WorldSpaceCameraPos );

				// get the falloff to the horizon
				float viewFalloff = 1.0 - saturate( dot( viewDir, float3(0,1,0) ) );

				// Add some up vector to the horizon to pull the clouds down
				float3 traceDir = normalize( viewDir + float3(0,viewFalloff * 0.1,0) );

				// Generate uvs from the world position of the sky
				float3 worldPos = _WorldSpaceCameraPos + traceDir * ( ( _CloudHeight - _WorldSpaceCameraPos.y ) / max( traceDir.y, 0.00001) );
				float3 uv = float3( worldPos.xz * 0.01 * _Scale, 1);

				// Figure out how for to move through the uvs for each step of the parallax offset
				//half3 uvStep = half3( traceDir.xz * _BumpOffset * ( 1.0 / traceDir.y), 1) * ( 1.0 / _Steps );
				//uv += uvStep * rand3( IN.worldPos + _SinTime.w );
				//uv += uvStep * ( IN.worldPos + _SinTime.w );

				float4 accColor = FogColorDensitySky(viewDir);
				float speed = _Speed * _Time.x;

				// wave distortion
				float3 coordsWave = float3( uv.xy *_TilingWave.xy + ( _TilingWave.zw * speed ), 0.0 );
				half3 wave = tex2D( _WaveTex, float4(coordsWave.xy,0,0) ).xyz;

				// first cloud layer
				float2 coords1 = uv.xy * _Tiling1.xy + ( _Tiling1.zw * speed );
				coords1 += ( wave.xy - 0.5 ) * _WaveDistort;
				half4 clouds = tex2D( _CloudTex1, float4(coords1.xy,0,0) );

				// add wave to cloud height
				clouds.w += ( wave.z - 0.5 ) * _WaveAmount;

				// scale and bias clouds because we are adding lots of stuff together
				// and the values cound go outside 0-1 range
				clouds.w = clouds.w * _CloudScale + _CloudBias;

				// overhead light color
				float3 coords4 = float3( uv.xy * _TilingColor.xy + ( _TilingColor.zw * speed ), 0.0 );
				half4 cloudColor = tex2D( _ColorTex, float4(coords4.xy,0,0)  );

				// cloud color based on density
				half cloudHightMask = 1.0 - saturate( clouds.w );
				cloudHightMask = pow( cloudHightMask, _ColPow );
				clouds.xyz *= lerp( _Color2.xyz, _Color.xyz * cloudColor.xyz * _ColFactor, cloudHightMask );

				// subtract alpha based on height
				half cloudSub = 1.0 - uv.z;
				clouds.w = clouds.w - cloudSub * cloudSub;

				// multiply density
				clouds.w = saturate( clouds.w * _CloudDensity );

				// add extra density
				clouds.w = saturate( clouds.w + 1 );

				// add Sunlight
				//clouds.xyz += sunTrans * cloudHightMask;

				// premultiply alpha
				clouds.xyz *= clouds.w;

				accColor += environment + clouds * ( 1.0 - accColor.w );

				// return the color!
				//accColor = float4(uv, 1);
				//accColor = float4(wave, 1);
				//accColor = float4(coordsWave, 1);
				//accColor = float4(coords1, 0, 1);
				//accColor = clouds;
				//accColor = float4(cloudsFlow, 1);
				//accColor = float4(coords1, 0, 1);
				//accColor = clouds2;
				//accColor = environment;
				//accColor = cloudColor;
				//accColor = float4(viewDir, 1);
				//accColor = viewFalloff;
				//accColor = float4(traceDir, 1);
				//accColor = float4(worldPos, 1);
				//accColor = float4(worldPos.xz, 1, 1);
				//accColor = float4(IN.worldPos, 1);
				//accColor = float4(IN.texcoord, 1);

				return accColor;
			}
			ENDCG
		}
	}
}