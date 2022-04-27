Shader "Learn/Triplanar"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Normal("Normal",2D) = "bump" {}
        _BlendPow("_BlendPow",Float) = 1.0
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
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float4 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 world_pos : TEXCOORD1;
                float3 world_normal : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _Normal;
            float _BlendPow;

            float3 triplanerObjNormal(sampler2D inputTex, float3 inputPos, float3 inputNormal, float power, float4 tilingAndOffSet) {
                // World Space
                // float3 world_origin = mul(unity_ObjectToWorld,float3(0,0,0));
                // float3 m_substance = i.world_pos.xyz - world_origin;
                // float3 m_normal = i.world_normal;

                //Object Space
                float3 object_pos = mul(unity_WorldToObject, inputPos);
                float3 m_substance = object_pos.xyz - float3(0, 0, 0);
                float3 m_normal = mul(unity_WorldToObject, inputNormal);

                float3 nsign = sign(m_normal);
                //三次采样
                float4 colXY = tex2D(inputTex, float2(-nsign.z, 1.0) * m_substance.xy * tilingAndOffSet.xy + tilingAndOffSet.zw);
                float4 colXZ = tex2D(inputTex, float2(nsign.y, 1.0) * m_substance.xz * tilingAndOffSet.xy + tilingAndOffSet.zw);
                float4 colZY = tex2D(inputTex, float2(nsign.x, 1.0) * m_substance.zy * tilingAndOffSet.xy + tilingAndOffSet.zw);

                //如果是法线贴图
                colZY.xyz = half3(UnpackNormal(colZY).xy * float2(nsign.x, 1.0) + m_normal.zy, m_normal.x).zyx;
                colXZ.xyz = half3(UnpackNormal(colXZ).xy * float2(nsign.y, 1.0) + m_normal.xz, m_normal.y).xzy;
                colXY.xyz = half3(UnpackNormal(colXY).xy * float2(-nsign.z, 1.0) + m_normal.xy, m_normal.z).xyz;

                //使用法线混合
                float3 projNormal = pow(abs(m_normal), power);
                projNormal /= (projNormal.x + projNormal.y + projNormal.z) + 0.00001;
                float3 triplan = projNormal.x * colZY.rgb + projNormal.y * colXZ.rgb + projNormal.z * colXY.rgb;
                return triplan;
            }

            float3 triplanerObj(sampler2D inputTex, float3 inputPos, float3 inputNormal, float power, float4 tilingAndOffSet) {
                // World Space
                // float3 world_origin = mul(unity_ObjectToWorld,float3(0,0,0));
                // float3 m_substance = i.world_pos.xyz - world_origin;
                // float3 m_normal = i.world_normal;

                //Object Space
                float3 object_pos = mul(unity_WorldToObject, inputPos);
                float3 m_substance = object_pos.xyz - float3(0, 0, 0);
                float3 m_normal = mul(unity_WorldToObject, inputNormal);

                float3 nsign = sign(m_normal);
                //三次采样
                float4 colXY = tex2D(inputTex, float2(-nsign.z, 1.0) * m_substance.xy * tilingAndOffSet.xy + tilingAndOffSet.zw);
                float4 colXZ = tex2D(inputTex, float2(nsign.y, 1.0) * m_substance.xz * tilingAndOffSet.xy + tilingAndOffSet.zw);
                float4 colZY = tex2D(inputTex, float2(nsign.x, 1.0) * m_substance.zy * tilingAndOffSet.xy + tilingAndOffSet.zw);

                //使用法线混合
                float3 projNormal = pow(abs(m_normal), power);
                projNormal /= (projNormal.x + projNormal.y + projNormal.z) + 0.00001;
                float3 triplan = projNormal.x * colZY.rgb + projNormal.y * colXZ.rgb + projNormal.z * colXY.rgb;
                return triplan;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.world_pos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.world_normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 baseColor = triplanerObj(_MainTex,i.world_pos,i.world_normal,_BlendPow,_MainTex_ST);
                float3 normal = triplanerObjNormal(_Normal, i.world_pos, i.world_normal, _BlendPow, _MainTex_ST);
                float3 light_dir = normalize(_WorldSpaceLightPos0);
                float NdotL = dot(light_dir, normal) * 0.5 + 0.5;
                return float4(baseColor * NdotL,1);
            }
            ENDCG
        }
    }
}
