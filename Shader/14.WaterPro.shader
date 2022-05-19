Shader "Learn/WaterPro"
{
    Properties
    {
       
        _DeepWaterColor("DeepSeaColor",Color) = (1,1,1,1)
        _ShallowWaterColor("ShallowWaterColor",Color) = (0,0,0,1)
        _ShoreSmooth("ShoreSmooth",Range(1.0,10.0)) = 1.0
        _fresnelColor("fresnelColor",Color) = (0,0,0,1)
        _fresnel("fresnel",Vector) = (0,1,5,0)
        _WaterNormal("WaterNormal", 2D) = "bump" {}
        _WaterNormalInstensity("WaterNormalInstensity" , Range(0.0,10.0)) = 1.0
        _WaterSpeed("WaterSpeed",Vector) = (1.0,0.0,0.0,0.0)
        _ReflectionTex("ReflectionTex",2D) = "black"{}
        _ReflectionInstensity("ReflectionInstensity",Range(0.01,5.0)) = 1.0

        _CausticsTex("CausticsTex", 2D) = "black" {}
        _CausticsTexScale("CausticsTexScale",Range(1.0,50.0)) = 1.0
        _CausticsSpeed("CausticsSpeed",Vector) = (1.0,-1.0,0.0,0.0)
        _CausticsInstensity("CausticsInstensity",Range(0.01,5.0)) = 1.0
        _CausticsRange("CausticsRange",Range(1.0,50.0)) = 1.0

        _ShoreWaterColor("ShoreWaterColor",Color) = (1,1,1,1)
        _ShoreStep("ShoreStep",Range(0.0,1.0)) = 0.0
        _SinWaveRange("SinWaveRange",Float) = 1.0
        _SinWaveSpeed("SinWaveSpeed",Float) = 1.0
        _SinWavePower("SinWavePower",Float) = 10
        _SinWaveMask("SinWaveMask",Range(0.0,1.0)) = 0.0
        _SinWaveNoise("SinWaveNoise",Vector) = (10,10,1,0)

        _WaveSpeed("WaveSpeed",Float) = 1.0
        _WaveScale("WaveScale", Float) = 1.0
        _WaveA ("Wave A", Vector) = (1,0,0.5,10)
		_WaveB ("Wave B", Vector) = (0,1,0.25,20)
		_WaveC ("Wave C", Vector) = (1,1,0.15,10)

        _SpecStartEnd("SpecStartEnd",Vector) = (0.0,200.0,0.0,0.0)
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
        LOD 100

        GrabPass{ }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityShaderVariables.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 screen_pos : TEXCOORD1;
                float3 worldSpaceDir : TEXCOORD2;
                float viewSpaceZ : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
                float3 normal : TEXCOORD5;
            };


            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            float4 _CameraDepthTexture_TexelSize;
            sampler2D _GrabTexture;

            float4 _DeepWaterColor;
            float4 _ShallowWaterColor;

            float _ShoreSmooth;
            float4 _fresnelColor;
            float3 _fresnel;
            sampler2D _WaterNormal;
            float4 _WaterNormal_ST;
            float2 _WaterSpeed;
            float _WaterNormalInstensity;

            sampler2D _ReflectionTex;
            float4 _ReflectionTex_ST;
            float _ReflectionInstensity;

            sampler2D _CausticsTex;
            float _CausticsTexScale;
            float2 _CausticsSpeed;
            float _CausticsInstensity;
            float _CausticsRange;
            float4 _ShoreWaterColor;
            float _ShoreStep;
            float _SinWaveRange;
            float _SinWaveSpeed;
            float _SinWavePower;
            float _SinWaveMask;
            float3 _SinWaveNoise;
            float _WaveSpeed, _WaveScale;
            float4 _WaveA, _WaveB, _WaveC;

            float2 _SpecStartEnd;

            //https://www.shadertoy.com/view/XdXGW8
            float2 GradientNoiseDir(float2 x)
            {
                const float2 k = float2(0.3183099, 0.3678794);
                x = x * k + k.yx;
                return -1.0 + 2.0 * frac(16.0 * k * frac(x.x * x.y * (x.x + x.y)));
            }

            float GradientNoise(float2 UV, float Scale)
            {
                float2 p = UV * Scale;
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f * f * (3.0 - 2.0 * f);
                return lerp(lerp(dot(GradientNoiseDir(i + float2(0.0, 0.0)), f - float2(0.0, 0.0)),
                    dot(GradientNoiseDir(i + float2(1.0, 0.0)), f - float2(1.0, 0.0)), u.x),
                    lerp(dot(GradientNoiseDir(i + float2(0.0, 1.0)), f - float2(0.0, 1.0)),
                        dot(GradientNoiseDir(i + float2(1.0, 1.0)), f - float2(1.0, 1.0)), u.x), u.y);
            }

            //https://catlikecoding.com/unity/tutorials/flow/waves/ 模拟水波顶点动画
            float3 GerstnerWave(float4 wave, float3 position, inout float3 tangent, inout float3 binormal, float waveSpeed, float scale)
            {

                float steepness = wave.z / scale;
                float wavelength = wave.w / scale;

                float k = 2 * 3.14 / wavelength;
                float c = sqrt(9.8 / k);
                float2 d = normalize(wave.xy);
                float f = k * (dot(d, position.xz) - (waveSpeed / scale) * _Time.y);
                float a = steepness / k;

                tangent += float3(1 - d.x * d.x * (steepness * sin(f)), d.x * (steepness * cos(f)), -d.x * d.y * (steepness * sin(f)));

                binormal += float3(-d.x * d.y * (steepness * sin(f)), d.y * (steepness * cos(f)), 1 - d.y * d.y * (steepness * sin(f)));


                return float3(d.x * (a * cos(f)), a * sin(f), d.y * (a * cos(f)));
            }

            v2f vert (appdata v)
            {
                v2f o;
                //水波纹顶点动画
                float3 gridPoint = v.vertex.xyz;
			    float3 tangent = float3(1, 0, 0);
			    float3 binormal = float3(0, 0, 1);
			    float3 p = gridPoint;
			    p += GerstnerWave(_WaveA, gridPoint, tangent, binormal, _WaveSpeed, _WaveScale);
			    p += GerstnerWave(_WaveB, gridPoint, tangent, binormal, _WaveSpeed, _WaveScale);
			    p += GerstnerWave(_WaveC, gridPoint, tangent, binormal, _WaveSpeed, _WaveScale);
			    float3 normal = normalize(cross(binormal, tangent));
			    v.vertex.xyz = p;
			   // v.normal = normal;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.texcoord;
                o.worldSpaceDir = WorldSpaceViewDir(v.vertex);
                o.viewSpaceZ = mul(UNITY_MATRIX_V, float4(o.worldSpaceDir, 0.0)).z;
                o.screen_pos = ComputeScreenPos(o.pos);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 view_dir = normalize(_WorldSpaceCameraPos - i.worldPos);

                //从深度纹理重建像素的世界空间位置 https://zhuanlan.zhihu.com/p/92315967
                float eyeDepth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.screen_pos)).r;
                eyeDepth = LinearEyeDepth(eyeDepth);
                i.worldSpaceDir *= -eyeDepth / i.viewSpaceZ; // Rescale the vector
                float3 worldPos_depth = _WorldSpaceCameraPos + i.worldSpaceDir;
                float shore = exp(-(i.worldPos.y - worldPos_depth.y) / _ShoreSmooth);
                shore = clamp(shore, 0, 1);
                float3 waterColor = lerp(_DeepWaterColor.rgb * _DeepWaterColor.a, _ShallowWaterColor.rgb * _ShallowWaterColor.a, shore);
                float fresnel = (_fresnel.x + _fresnel.y * pow(max(1.0 - dot(view_dir, i.normal), 0.0001), _fresnel.z));
                waterColor = lerp(waterColor, _fresnelColor, fresnel);
                //反射与水面法线
                //waterNormal偏移
                float2 screen_uv = i.screen_pos.xy / i.screen_pos.w;
                float2 uv_WaterNormal = i.uv * _WaterNormal_ST.xy + _WaterNormal_ST.zw;
                float2 waterUV = uv_WaterNormal + _Time.x * _WaterSpeed;
                float3 waterNormal = UnpackNormal(tex2D(_WaterNormal, waterUV));
                float2 waterUV2 = uv_WaterNormal + _Time.x * (-_WaterSpeed);
                float3 waterNormal2 = UnpackNormal(tex2D(_WaterNormal, waterUV2));
                waterNormal = BlendNormals(waterNormal, waterNormal2);
                //削弱视野远处waterNormal tilling值
                waterNormal.xy = waterNormal.xy / (i.pos.w + 1.0);
                float2 reflectUV = screen_uv + waterNormal.xy * _WaterNormalInstensity;
                float3 reflectionColor = tex2D(_ReflectionTex, reflectUV) * _ReflectionInstensity;
                reflectionColor += waterColor;
                //摇动水底
                float3 underwaterColor = tex2D(_GrabTexture, reflectUV);
                //焦散效果
                float2 causticsUV1 = (worldPos_depth.xz / _CausticsTexScale) + (_CausticsSpeed * _Time.x );
                float2 causticsUV2 = -(worldPos_depth.xz / _CausticsTexScale) + (_CausticsSpeed * _Time.x);
                float causticsRange = clamp(exp(-worldPos_depth.z / _CausticsRange), 0.0, 1.0);
                float3 causticsColor1 = tex2D(_CausticsTex, causticsUV1) * _CausticsInstensity * causticsRange;
                float3 causticsColor2 = tex2D(_CausticsTex, causticsUV2) * _CausticsInstensity * causticsRange;
                float3 causticsColor = min(causticsColor1, causticsColor2);
                causticsColor *= 1.0 -shore;
                //岸边水体
                float shoreStep = smoothstep(_ShoreStep, 1, shore);
                float3 shoreColor = _ShoreWaterColor.rgb  * shoreStep * _ShoreWaterColor.a;
                //sin波
                float sinWaveRange = clamp(exp(-(i.worldPos.y - worldPos_depth.y) / _SinWaveRange),0,1);
                float sinWaveStep = smoothstep(_SinWaveMask, 1, shore);
                float sinWave = clamp(sin(_SinWaveSpeed * _Time.x + sinWaveRange * _SinWavePower) * sinWaveStep,0,1);
                //程序化噪点图
                float gradientNoise = clamp(GradientNoise(i.uv * _SinWaveNoise.xy, _SinWaveNoise.z),0,1);
                sinWave = step(0.5,sinWave - gradientNoise) * sinWaveStep;

                float3 finalColor = lerp(reflectionColor, underwaterColor, shore);
                finalColor = finalColor + causticsColor + shoreColor + sinWave;
                ////线性雾方式柔化远端
                //float m_distance = distance(i.worldPos, _WorldSpaceCameraPos);
                //float m_linefog = clamp((_SpecStartEnd.y - m_distance) / (_SpecStartEnd.y - _SpecStartEnd.x), 0.0, 1.0);
                //finalColor = finalColor * m_linefog;

                return float4(finalColor.rgb  , 1.0);
            }
            ENDCG
        }
    }
}