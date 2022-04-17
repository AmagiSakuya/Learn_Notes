Shader "Learn/OverHitCharHair"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalMap("Normal", 2D) = "bump" {}
        _NormalStrength("NormalStrength",Range(-1.0,1.0)) = 1.0
        _AnisoMap("_AnisoMap",2D ) = "gray" {}

        _SpecColor1("Specular Color",Color) =(1,1,1,1)
        _SpecShininess1("Spec Shininess",Range(0.0,1.0)) = 0.1
        _SpecNoise1( "Spec Noise",Range(-1.0,1.0))= 0
        _SpecOffset1("Spec Offset",Range(-1.0,1.0)) = 0

        _SpecColor2("Specular Color_2",Color) =(1,1,1,1)
        _SpecShininess2("Spec Shininess_2",Range(0.0,1.0)) = 0.1
        _SpecNoise2( "Spec Noise_2",Range(-1.0,1.0))= 0
        _SpecOffset2("Spec Offset_2",Range(-1.0,1.0)) = 0

        _EnvCubeMap("EnvCubeMap",CUBE) = ""{}
        _EnvCubeRotate("EnvCubeRotate",Range(-1,1)) = 0.0

        _FresnelCol("FresnelCol ",COLOR) = (1,1,1,1)
        _FresnelScale("FresnelScale ",Range(0.0,1.0)) = 0.0
        
        [Space(50)]
        custom_SHAr("Custom SHAr", Vector) = (0,0,0,0)
        custom_SHAg("Custom SHAg",Vector) = (0,0,0,0)
        custom_SHAb("Custom SHAb",Vector) = (0,0,0,0)
        custom_SHBr("Custom SHBr",Vector) = (0,0,0,0)
        custom_SHBg("Custom SHBg", Vector) = (0,0,0,0)
        custom_SHBb("Custom SHBb",Vector) = (0,0,0,0)
        custom_SHC("Custom SHC", Vector)= (0,0,0,1)

        [Toggle] _DIRRECT_DIFFUSE("DIRRECT_Diffuse",Float) = 1
        [Toggle] _DIRRECT_SPEC("DIRRECT_SPEC",Float) = 1
        [Toggle] _INDIRRECT_DIFFUSE("INDIRRECT_DIFFUSE",Float) = 1
        [Toggle] _INDIRRECT_SPEC("INDIRRECT_SPEC",Float) = 1
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

            #pragma multi_compile _ _DIRRECT_DIFFUSE_ON
            #pragma multi_compile _ _DIRRECT_SPEC_ON
            #pragma multi_compile _ _INDIRRECT_DIFFUSE_ON
            #pragma multi_compile _ _INDIRRECT_SPEC_ON

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
            sampler2D _AnisoMap;
            float4 _AnisoMap_ST;

            float4 _SpecColor1;
            float _SpecShininess1;
            float _SpecNoise1;
            float _SpecOffset1;

            float4 _SpecColor2;
            float _SpecShininess2;
            float _SpecNoise2;
            float _SpecOffset2;

            samplerCUBE _EnvCubeMap;
            float4 _EnvCubeMap_HDR;
            float _EnvCubeRotate;
            float _FresnelScale;
            float4 _FresnelCol;

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
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal); // normalize(mul(v.normal, unity_WorldToObject));
                o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent));
                o.SHLighting = ShadeSH9(float4(o.normal, 1));
                UNITY_TRANSFER_SHADOW(o, o.uv);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                
                float3 view_dir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 binormal = normalize(cross(i.normal, i.tangent.xyz) * i.tangent.w );
                float3x3 TBN = float3x3(normalize(i.tangent.xyz), normalize(binormal), normalize(i.normal));
                float3 view_tangentSpace = normalize(mul(TBN,view_dir));
                #ifdef USING_DIRECTIONAL_LIGHT
                    float3 light_dir = normalize(_WorldSpaceLightPos0);
                #else
                    float3 light_dir = normalize(_WorldSpaceLightPos0 - i.worldPos);
                #endif 
                
                float4 normalMap = tex2D(_NormalMap, i.uv); //法线贴图
                float3 normal_data = UnpackNormal(normalMap);
                float3 normal = normalize(i.tangent * normal_data.x * _NormalStrength + binormal * normal_data.y * _NormalStrength + i.normal * normal_data.z);


                float4 albedo = tex2D(_MainTex, i.uv);
                
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                //直接漫反射
                //float lightModel = (dot(light_dir, normal) + 1) * 0.5;
                float diffuse_term = max(0, dot(light_dir, normal));
                float half_lambert = (diffuse_term *0.5 + 0.5);
                
                #ifdef _DIRRECT_DIFFUSE_ON
                    float3 directDiffuse = half_lambert* albedo;
                #else
                    float3 directDiffuse = float3(0,0,0);
                #endif

                //直接高光 (各向异性高光)
                float uv_aniso = i.uv * _AnisoMap_ST.xy + _AnisoMap_ST.zw;
                float aniso_noise = (tex2D(_AnisoMap, uv_aniso).r - 0.5)*2;

                float3 half_dir = normalize(light_dir + view_dir);
                float  NdotH = dot(normal , half_dir);
                float TdotH = dot(half_dir,i.tangent);

                float NdotV = max(0.0,dot(normal,view_dir));
                float aniso_atten = saturate(sqrt(max(0.0,half_lambert / NdotV ))) * atten; 
                
                float3 aniso_offset = normal * (aniso_noise * _SpecNoise1 + _SpecOffset1);
                float3 binormal_aniso = normalize(binormal + aniso_offset);
                float3 BdotH = dot(half_dir,binormal_aniso) / _SpecShininess1;
                float3 spec_term = exp(-(TdotH * TdotH + BdotH * BdotH)/(1.0 + NdotH));

                float3 aniso_offset_2 = normal * (aniso_noise * _SpecNoise2 + _SpecOffset2);
                float3 binormal_aniso_2 = normalize(binormal + aniso_offset_2);
                float3 BdotH_2 = dot(half_dir,binormal_aniso_2) / _SpecShininess2;
                //float3 spec_term = sqrt(1.0 - BdotH * BdotH);
                float3 spec_term_2 = exp(-(TdotH * TdotH + BdotH_2 * BdotH_2)/(1.0 + NdotH));
                
                #ifdef _DIRRECT_SPEC_ON
                    float3 directSpec = (spec_term * _SpecColor1  +spec_term_2* _SpecColor2)* _LightColor0 * aniso_atten;
                #else
                    float3 directSpec = float3(0,0,0);
                #endif 

                //间接漫反射 （离线球谐）
                #ifdef _INDIRRECT_DIFFUSE_ON
                    float3 indirDiffuse = custoumSH(normal) * albedo;
                #else
                    float3 indirDiffuse = float3(0,0,0);
                #endif 

                
                //间接镜面反射
                float3 reflect_dir = reflect(-view_dir, normal);
                float theta = _EnvCubeRotate * UNITY_PI;
                float2x2 m_rot = float2x2(cos(theta), -sin(theta), sin(theta), cos(theta));
                float2 dir_rot = mul(m_rot, reflect_dir.zx);
                reflect_dir = float3(dir_rot.x, dir_rot.y, dir_rot.y);
                float4 env_color = texCUBE(_EnvCubeMap, reflect_dir);
                float3 env_decode_color = DecodeHDR(env_color, _EnvCubeMap_HDR);

                #ifdef _INDIRRECT_SPEC_ON
                    float3 indirSpec = env_decode_color * albedo;
                #else
                    float3 indirSpec = float3(0,0,0);
                #endif 

                //Base Light Mode
                float3 finalColor = directDiffuse + directSpec + indirDiffuse + indirSpec;

                //blend fresnel
                float3 fresnel = _FresnelScale*pow( 1 - dot( view_dir,  normal), 5 ); //菲涅尔近似等式
                finalColor = lerp(finalColor.rgb, _FresnelCol, fresnel);

                return float4(finalColor ,1);
            }
            ENDCG
        }

        // Pass {
            //    Name "ShadowCaster"
            //    Tags { "LightMode" = "ShadowCaster" }
            //    CGPROGRAM
            //    #pragma vertex vert
            //    #pragma fragment frag
            //    #pragma target 2.0
            //    #pragma multi_compile_shadowcaster
            //    #pragma multi_compile_instancing // allow instanced shadow pass for most of the shaders
            //    #include "UnityCG.cginc"
            //    struct v2f {
                //        V2F_SHADOW_CASTER;
                //        UNITY_VERTEX_OUTPUT_STEREO
            //    };
            //    v2f vert( appdata_base v )
            //    {
                //        // hackity hack hack hack!
                //        // prevents the bias settings from having any affect on this shader's shadows
                //        unity_LightShadowBias = float4(0,0,0,0);
                
                //        v2f o;
                //        UNITY_SETUP_INSTANCE_ID(v);
                //        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                //        TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                //        return o;
            //    }
            //    float4 frag( v2f i ) : SV_Target
            //    {
                //        SHADOW_CASTER_FRAGMENT(i)
            //    }
            //    ENDCG
        //}
    }
    Fallback "Diffuse"
}
