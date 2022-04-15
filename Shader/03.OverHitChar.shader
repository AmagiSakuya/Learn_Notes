Shader "Learn/OverHitChar"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalMap("Normal", 2D) = "bump" {}
        _NormalStrength("NormalStrength",Range(-1.0,1.0)) = 1.0
        _CompMask("CompMask[AO/Metal]", 2D) = "white" {}
        _SpecSmooth("SpecSmooth",Range(0.01,100.0)) = 1.0
        _SpecInensity("SpecInensity",Range(0.01,100.0)) = 1.0

        _EnvCubeMap("EnvCubeMap",CUBE) = ""{}
        _EnvCubeRotate("EnvCubeRotate",Range(-1,1)) = 0.0
    
        _SSS_Skin_RampMap("SSS_Skin_RampMap", 2D) = "black" {}
        _CurveFactor("_CurveFactor ",Range(0.0,1.0)) = 0.0
        _FresnelScale("_FresnelScale ",Range(-1.0,1.0)) = 0.0

        [Space(50)]
        custom_SHAr("Custom SHAr", Vector) = (0,0,0,0)
        custom_SHAg("Custom SHAg",Vector) = (0,0,0,0)
        custom_SHAb("Custom SHAb",Vector) = (0,0,0,0)
        custom_SHBr("Custom SHBr",Vector) = (0,0,0,0)
        custom_SHBg("Custom SHBg", Vector) = (0,0,0,0)
        custom_SHBb("Custom SHBb",Vector) = (0,0,0,0)
        custom_SHC("Custom SHC", Vector)= (0,0,0,1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags {"LightMode" = "ForwardBase"} //ForwardAdd
            //Blend One One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fwdbase //#pragma multi_compile_fwdadd 

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float4 worldPos:TEXCOORD3;
                UNITY_SHADOW_COORDS(4)
                float3  SHLighting : COLOR;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NormalMap;
            float _NormalStrength;
            sampler2D _CompMask;
            float _SpecSmooth;
            float _SpecInensity;
            samplerCUBE _EnvCubeMap;
            float4 _EnvCubeMap_HDR;
            float _EnvCubeRotate;
            sampler2D _SSS_Skin_RampMap;
            float _CurveFactor;
            float _FresnelScale;

            float4 custom_SHAr;
            float4 custom_SHAg;
            float4 custom_SHAb;
            float4 custom_SHBr;
            float4 custom_SHBg;
            float4 custom_SHBb;
            float4 custom_SHC;

            float3 custoumSH(float3 normal) {
                float4 normalForSH = float4(normal, 1.0);
                half3 x;
                x.r = dot(custom_SHAr, normalForSH); 
                x.g = dot(custom_SHAg, normalForSH); 
                x.b = dot(custom_SHAb, normalForSH);
                half3 x1,x2;
                half4 vB = normalForSH.xyzz * normalForSH.yzzx; 
                x1.r = dot(custom_SHBr,vB);
                x1.g = dot(custom_SHBg,vB); 
                x1.b = dot(custom_SHBb, vB);

                half vC = normalForSH.x * normalForSH.x - normalForSH.y * normalForSH.y;
                x2 = custom_SHC.rgb * vC;

                float3 sh = max(float3(0.0,0.0,0.0),(x + x1 + x2)); 
                sh = pow(sh,1.0 / 2.2);
                return sh;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal); // normalize(mul(v.normal, unity_WorldToObject));
                o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent));
                o.SHLighting = ShadeSH9(float4(o.normal, 1));
                UNITY_TRANSFER_SHADOW(o, o.uv);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                
                float3 view_dir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w;
                float3x3 TBN = float3x3(normalize(i.tangent.xyz), normalize(binormal), normalize(i.normal));
                float3 view_tangentSpace = normalize(mul(TBN,view_dir));
                #ifdef USING_DIRECTIONAL_LIGHT
                    float3 light_dir = normalize(_WorldSpaceLightPos0);
                #else
                    float3 data.light_dir = normalize(_WorldSpaceLightPos0 - data.worldPos);
                #endif 

                float4 normalMap = tex2D(_NormalMap, i.uv); //法线贴图
                float3 normal_data = UnpackNormal(normalMap);
                float3 normal = normalize(i.tangent * normal_data.x * _NormalStrength + binormal * normal_data.y * _NormalStrength + i.normal * normal_data.z);

                //Mask贴图
                float4 maskTex = tex2D(_CompMask, i.uv);
                
                float roughness = maskTex.r;
                float metal = maskTex.g;
                float skinMask = (1.0 - maskTex.b);
                float4 albedo = tex2D(_MainTex, i.uv);

                //区分金属部分
                float3 base_metal_color = lerp(0, albedo, metal);
               
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                //直接漫反射
                //float lightModel = (dot(light_dir, normal) + 1) * 0.5;
                float diffuse_term = max(0, dot(light_dir, normal));

                //SSS_Skin_RampMask 
                float cuv = saturate(_CurveFactor * (length(fwidth(normal)) / length(fwidth(i.worldPos))));
                float2 skinUV = float2(diffuse_term * 0.5 + 0.5, cuv);
                float3 sssSkinRamp = tex2D(_SSS_Skin_RampMap, skinUV) * skinMask;
               
                float3 directDiffuse = (albedo * sssSkinRamp + albedo * (1.0 - skinMask) * diffuse_term) * atten  * _LightColor0.rgb;
               
                //sampler2D _SSS_Skin_RampMap;
                //float _RampMapOffset;

                //直接高光
                float3 blin_reflect_dir = normalize(light_dir + view_dir);
                float NdotR = dot(normal, blin_reflect_dir);
                float smoothness = 1.0 - roughness;
                float shininess = lerp(1, _SpecSmooth, smoothness);
                float3 spec_color_model = pow(max(0.0, NdotR), shininess * smoothness);
                float3 directSpec = base_metal_color * spec_color_model * _LightColor0 * _SpecInensity;

                //间接漫反射 （离线球谐）
                float3 fresnel = _FresnelScale + (1 - _FresnelScale) * pow(1 - dot(view_dir, normal), 5); //菲涅尔近似等式
                float3 indirDiffuse = custoumSH(normal) * albedo;
                //indirDiffuse = fresnel * indirDiffuse + indirDiffuse;
                //间接镜面反射
                float3 reflect_dir = reflect(-view_dir, normal);
                float theta = _EnvCubeRotate * UNITY_PI;
                float2x2 m_rot = float2x2(cos(theta), -sin(theta), sin(theta), cos(theta));
                float2 dir_rot = mul(m_rot, reflect_dir.zx);
                reflect_dir = float3(dir_rot.x, dir_rot.y, dir_rot.y);
                float4 env_color = texCUBE(_EnvCubeMap, reflect_dir);
                float3 env_decode_color = DecodeHDR(env_color, _EnvCubeMap_HDR);
                float3 indirSpec = env_decode_color * base_metal_color;
                
               

                float3 finalColor = directDiffuse + directSpec + indirDiffuse + indirSpec;

                return float4(finalColor,1);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
