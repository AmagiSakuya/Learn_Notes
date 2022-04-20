Shader "Hidden/ImageEffectShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _TestUseTex("TestUseTex", 2D) = "black" {}
        _TexSelect("TexSelect",Range(0,1)) = 0
        _Brightness("Brightness",Float) = 1

         _Saturation("Saturation",Float) = 1
        _Contrast("Contrast",Float) = 1
        _VignetteIntensity("VignetteIntensity",Range(0.05,3.0)) = 1.5
        _VignetteRoundness("VignetteRoundness",Range(1,6)) = 5
        _VignetteSmoothness("VignetteSmoothness",Range(0.05,5)) = 5
        _HueShift("HueShift",Range(0,1)) = 0
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 screen_pos : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                //o.screen_pos = o.pos;
                //o.screen_pos.y = o.screen_pos.y * _ProjectionParams.x;
                o.screen_pos = ComputeScreenPos(o.pos);
                return o;
            }

            sampler2D _MainTex;
            sampler2D _TestUseTex;
            float _TexSelect;

            float _Brightness;
            float _Saturation;
            float _Contrast;
            float _VignetteIntensity;
            float _VignetteRoundness;
            float _VignetteSmoothness;
            float _HueShift;

            float3 HSVToRGB(float3 c)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
            }

            float3 RGBToHSV(float3 c)
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }

            half4 frag(v2f_img i) : SV_Target
            {
                //float2 screen_uv = i.screen_pos.xy / (i.screen_pos.w + 0.000001);
                //screen_uv = (screen_uv + 1.0) * 0.5;
                
                float4 colMain = tex2D(_MainTex, i.uv);
                float4 colTest = tex2D(_TestUseTex, i.uv);
                float4 col = lerp(colMain, colTest, _TexSelect);
                float3 finalColor = col.rgb;

                //色相
                float3 hsv = RGBToHSV(finalColor);
                hsv.r = hsv.r + _HueShift;
                finalColor = HSVToRGB(hsv);
                //亮度
                finalColor *= _Brightness;
                //饱和度
                float lumin = dot(finalColor, float3(0.22, 0.707, 0.071));
                finalColor = lerp(lumin, finalColor, _Saturation);
                //对比度
                float3 midpoint = float3(0.5, 0.5, 0.5);
                finalColor = lerp(midpoint, finalColor, _Contrast);
                //暗角/晕影
                float2 d = abs(i.uv - half2(0.5, 0.5)) * _VignetteIntensity;
                d = pow(saturate(d), _VignetteRoundness);
                float dist = length(d);
                float vfactor = pow(saturate(1.0 - dist * dist), _VignetteSmoothness);
                finalColor = finalColor * vfactor;
                //反色
                //finalColor = 1 - finalColor;

                return float4(finalColor,col.a);
            }
            ENDCG
        }
    }
}
