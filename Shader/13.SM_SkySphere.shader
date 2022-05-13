Shader "Unlit/SM_SkySphere"
{
    Properties
    {
        [NoScaleOffset] _CubeMap("CubeMap",CUBE) = "grey"{}
        _Tint("Tint Color", Color) = (.5, .5, .5, .5)
        [Gamma] _Exposure("Exposure", Range(0, 8)) = 1.0
        _Rotation("Rotation", Range(0, 360)) = 0
    }
    SubShader
    {
        Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" }
        Cull Back
        //ZWrite Off

        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float3 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 world_pos : TEXCOORD1;
                float3 world_normal:TEXCOORD2;
            };

            samplerCUBE _CubeMap;
            float4 _CubeMap_HDR;
            float4 _Tint;
            float _Exposure;
            float _Rotation;

            float3 RotateAroundYInDegrees(float3 vertex, float degrees)
            {
                float alpha = degrees * UNITY_PI / 180.0;
                float sina, cosa;
                sincos(alpha, sina, cosa);
                float2x2 m = float2x2(cosa, -sina, sina, cosa);
                return float3(mul(m, vertex.xz), vertex.y).xzy;
            }

            v2f vert (appdata v)
            {
                v2f o;
                float3 rotated = RotateAroundYInDegrees(v.vertex, _Rotation);
                o.pos = UnityObjectToClipPos(rotated);
                //²»Ότ²Γ
                #if UNITY_REVERSED_Z
                    o.pos.z = o.pos.w * 0.000001f; 
                #else
                    o.pos.z = o.pos.w * 0.999999f; 
                #endif

                o.uv = v.vertex.xyz;
                o.world_pos = mul(unity_ObjectToWorld, v.vertex);
                o.world_normal = UnityObjectToWorldNormal(v.normal);

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float4 env_color = texCUBE(_CubeMap, i.uv);
                float3 env_decode_color = DecodeHDR(env_color, _CubeMap_HDR);
                env_decode_color = env_decode_color * _Tint.rgb * unity_ColorSpaceDouble.rgb;
                env_decode_color *= _Exposure;
                return float4(env_decode_color,1.0);
            }
            ENDCG
        }
    }
}
