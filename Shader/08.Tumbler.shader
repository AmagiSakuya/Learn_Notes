Shader "Unlit/Tumbler"
{
    Properties
    {
        _BaseColor("BaseColor",Color) = (0.5,0.5,0.5,1)
        _MatCap ("MatCap", 2D) = "white" {}
        _ThicknessMap("ThicknessMap", 2D) = "black" {}
        _ThicknessSmooth("ThicknessSmooth",Vector) = (0.2,0.7,0.0,0.0)
        _ThicknessStrength("_ThicknessStrength",Range(0.0,1.0)) = 1.0
        _RefractionMap("RefractionMap", 2D) = "white" {}
        _ReflactStrength("ReflactStrength",Range(0.0,10.0)) = 1.0
        _RefractInstensity("RefractInstensity",Range(0.0,10.0)) = 1.0
        _Fresnel("_Fresnel",Vector) = (0.0,1.0,5.0,0.0)
        _Fingerprint("Fingerprint", 2D) = "black" {}
        _FingerprintInstensity("FingerprintInstensity",Range(0.0,1.0)) = 1.0
        _Logo("_Logo", 2D) = "black" {}
        _Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent" }
        LOD 100

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
           
            #include "UnityCG.cginc"
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
                float3 world_pos : TEXCOORD1;
                float3 world_normal : TEXCOORD2;
                UNITY_SHADOW_COORDS(3)
            };

            float4 _BaseColor;
            sampler2D _MatCap;
            float4 _MatCap_ST;
            sampler2D _ThicknessMap;
            float2 _ThicknessSmooth;
            float _ThicknessStrength;
            sampler2D _RefractionMap;
            float _ReflactStrength;
            float _RefractInstensity;
            float3 _Fresnel;
            sampler2D _Fingerprint;
            float _FingerprintInstensity;
            sampler2D _Logo;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MatCap);
                o.world_pos = mul(unity_ObjectToWorld, v.vertex);
                o.world_normal = UnityObjectToWorldNormal(v.normal);
                UNITY_TRANSFER_SHADOW(o, o.uv);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float3 view_dir = normalize(_WorldSpaceCameraPos - i.world_pos);
                //MatCap 反射图
                float3 view_pos = mul(UNITY_MATRIX_V, float4(i.world_pos, 1.0));
                float3 view_normal = mul(UNITY_MATRIX_V, i.world_normal);
                float3 view_pcn = cross(normalize(view_pos), normalize(view_normal));
                float2 matCapUV = float2(-view_pcn.y, view_pcn.x)* 0.5 + 0.5;
                //float2 matCapUV_Classic = (view_normal * 0.5 + 0.5).xy;
                float4 matCapColor = tex2D(_MatCap, matCapUV);

                //厚度图
                float thicknessColor = tex2D(_ThicknessMap, i.uv).r;
                thicknessColor = smoothstep(_ThicknessSmooth.x, _ThicknessSmooth.y,thicknessColor) * _ThicknessStrength;
                //边缘折射
                float VdotN = dot(view_dir, i.world_normal);
                float fresnel = _Fresnel.x + _Fresnel.y * pow(1.0 - VdotN, _Fresnel.z);
                float refactArea = fresnel + thicknessColor * _RefractInstensity;
                //折射图
                float4 refractTex = tex2D(_RefractionMap, matCapUV + thicknessColor * _ReflactStrength);
                float4 refractColor = refractTex * refactArea;
                //指纹图
                float4 fingerprint = tex2D(_Fingerprint, i.uv);
                //Logo
                float4 logo = tex2D(_Logo, i.uv);
                //Emssion
                float3 Emssion = refractColor.rgb + matCapColor.rgb;
                Emssion = lerp(Emssion, fingerprint.rgb * _FingerprintInstensity, fingerprint.a);
                Emssion = lerp(Emssion, logo.rgb, logo.a);
                //透明度
                float opacity = max(refactArea.r, matCapColor.r);
                opacity = max(opacity, fingerprint.a * _FingerprintInstensity);
                opacity = max(opacity, logo.a);

                Emssion = lerp(_BaseColor, Emssion, opacity);
                //_BaseColor
                return float4(Emssion, opacity);
            }
            ENDCG
        }

    }
}
