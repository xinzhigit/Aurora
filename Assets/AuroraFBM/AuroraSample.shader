Shader "Aurora/AuroraSample" {
    Properties {
        _MainTex ("Main Tex", 2D) = "black" {}

        [Header(Aurora Setting)]
        [HDR]_AuroraColor ("Aurora Color", Color) = (1,1,1,0)
        _AuroraIntensity("Aurora Intensity", Range(1,100)) = 1
        _AuroraSpeed("AuroraSpeed", Range(0,1)) = 0.5
        _SurAuroraColFactor("Sur Aurora Color Factor", Range(0,1)) = 0.5
        _AuroraStep("Aurora Step", Range(0,100)) = 10

        _AuroraNoiseTex ("Aurora Noise Tex", 2D) = "white" {}
    }

    CGINCLUDE

    #include "UnityCG.cginc"

    struct appdata {
        float4 position : POSITION;
        float3 texcoord : TEXCOORD0;
        float3 normal : NORMAL;
    };
    
    struct v2f {
        float4 position : SV_POSITION;
        float3 texcoord : TEXCOORD0;
        float3 normal : TEXCOORD1;
    };

    sampler2D _MainTex;

    // 极光
    half4 _AuroraColor;
    half _AuroraIntensity;
    half _AuroraSpeed;
    half _SurAuroraColFactor;
    half _AuroraStep;
    sampler2D _AuroraNoiseTex;

        // 旋转矩阵
    float2x2 RotateMatrix(float a) {
        float c = cos(a);
        float s = sin(a);
        return float2x2(c,s,-s,c);
    }

    float SurHash(float2 n){
         return frac(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453); 
    }

    float4 SurAurora(float3 pos,float3 ro) {
        float4 col = float4(0,0,0,0);
        float4 avgCol = float4(0,0,0,0);



        // 逐层
        for(int i=0;i<_AuroraStep;i++)
        {
            // 坐标
            //float of = 0.006*SurHash(pos.xy)*smoothstep(0,15, i);       
            float pt = ((0.8+pow(i,1.4)*0.002)-ro.y)/(pos.y*2.0+0.8);
            //pt -= of;
            float3 bpos = ro + pt*pos;
            float2 p = bpos.zx;
            p = mul(RotateMatrix(_Time.y*_AuroraSpeed), p);

            // 颜色
            //float2 p = mul(RotateMatrix(_Time.y*_AuroraSpeed), pos.zx);
            //float2 p = _Time.y * _AuroraSpeed * pos.xy;

            //float noise = tex2D(_AuroraNoiseTex, p).r;
            //float4 col2 = float4(0,0,0, noise);
            //col2.rgb = (sin(1.0-float3(2.15,-.5, 1.2)+i*_SurAuroraColFactor*0.1)*0.8+0.5)*noise;
            //avgCol =  lerp(avgCol, col2, 0.5);
            //col += avgCol*exp2(-i*0.065 - 2.5)*smoothstep(0.,5., i);

            float noise = tex2D(_AuroraNoiseTex, p).r;
            float4 col2 = float4(0,0,0, noise);
            col2.rgb = (sin(1.0-float3(2.15,-.5, 1.2)+i*_SurAuroraColFactor))*noise * _AuroraIntensity;
            avgCol = lerp(avgCol, col2, 0.5);
            col += avgCol*exp2(-i*0.065 - 2.5)*smoothstep(0.,5., i);
        }

        col *= (clamp(pos.y*15.+.4,0.,1.));

        return col*1.8;

    }

    v2f vert (appdata v)
    {
        v2f o;
        o.position = UnityObjectToClipPos (v.position);
        o.texcoord = v.texcoord;
        o.normal = v.normal;
        return o;
    }

    half4 frag (v2f i) : COLOR
    {
        float4 skyCol = tex2D(_MainTex, i.texcoord);

        //带状极光
        float4 surAuroraCol = smoothstep(0.0,1.5,SurAurora(
                                                    float3(i.texcoord.x,i.texcoord.y,i.texcoord.z),
                                                    float3(0,0,-6.7)));

        //混合
        //float4 skyCol = (_Color1 * p1 + _Color2 * p2 + _Color3 * p3) * _Intensity;
        skyCol = skyCol*(1 - surAuroraCol.a) + surAuroraCol * surAuroraCol.a;

        return skyCol;
    }

    ENDCG

    SubShader {
        Tags { "RenderType"="Background" "Queue"="Background" }
        Pass
        {
            ZWrite Off
            Cull Off
            Fog { Mode Off }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDCG
        }
    } 
}
