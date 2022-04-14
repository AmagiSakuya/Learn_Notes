// 玉石材质
Shader "Learn/Jade"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
        _MainTexColor("MainTexColor",Color) = (1,1,1,1)
        _CubeMap("HighLightMap",CUBE) = ""{}
        _HighLightMapRotate("HighLightMapRotate",Range(-1,1)) = 0.0
        _HighLightPower("HighLightPower",Range(0.0,1.0)) = 1.0
        _RefringencePower("RefringencePower",Range(0.0,10.0)) = 1.0
        _TranslucentPower("TranslucentPower",Range(0.0,10.0)) = 1.0
        _TranslucentInst("TranslucentInst",Range(0.0,10.0)) = 1.0
        _ThicknessMap("ThicknessMap",2D) = "white" {}
        _SkyLightPower("SkyLightPower",Range(0.0,1.0)) = 0.0
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
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;

            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal : TEXCOORD1;
                float3 worldPos:TEXCOORD2;
                UNITY_SHADOW_COORDS(3)
            };

            sampler2D _MainTex;
            sampler2D _ThicknessMap;

            float4 _MainTex_ST;
            float4 _MainTexColor;
            samplerCUBE _CubeMap;
            float4 _CubeMap_HDR;
            float _RefringencePower;
            float _TranslucentPower;
            float _TranslucentInst;
            float _SkyLightPower; 
            float _HighLightMapRotate;
            float _HighLightPower;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                UNITY_TRANSFER_SHADOW(o, v.uv);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                
                float3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                float3 normal = normalize(i.normal);

                #ifdef USING_DIRECTIONAL_LIGHT
                    float3 light_dir = normalize(_WorldSpaceLightPos0);
                #else
                    float3 light_dir = normalize(_WorldSpaceLightPos0 - i.worldPos);
                #endif 

                float3 finalColor;
                //漫反射
                float NLDot = max(0, dot(light_dir, normal));
                float4 mainTex = tex2D(_MainTex, i.uv);
                float3 diffuseColor = mainTex * NLDot * _MainTexColor * _LightColor0;
                finalColor = diffuseColor;
                
                //SkyLight
                float SkyDot = max(0,(dot(float3(0,1,0), normal)));
                float3 skycolor = mainTex * SkyDot* _MainTexColor* _LightColor0 * _SkyLightPower;
                finalColor += skycolor;
                
                //环境Cube
                float3 reflect_dir = reflect(-view_dir, normal);
                float theta = _HighLightMapRotate * UNITY_PI ;
                float2x2 m_rot = float2x2(cos(theta), -sin(theta), sin(theta), cos(theta));
                float2 dir_rot = mul(m_rot, reflect_dir.zx);
                reflect_dir = float3(dir_rot.x, dir_rot.y, dir_rot.y);
                float4 env_color = texCUBE(_CubeMap, reflect_dir);
                float3 env_decode_color = DecodeHDR(env_color, _CubeMap_HDR);
                //fresenl
                float fresenl = 1.0 - max(0, dot(view_dir, normal));
                env_decode_color = env_decode_color * fresenl * _HighLightPower;
                finalColor += env_decode_color;
                

                //透光效果
                //光线折射
                float3 refringenceDir = -normalize(light_dir + normal * _RefringencePower);
                float VLDot = max(0, dot(view_dir, refringenceDir));
                VLDot = pow(VLDot, _TranslucentPower) * _TranslucentInst;
                float3 refringenceColor = VLDot * _MainTexColor * mainTex * _LightColor0;
                float4 thicknessMap = tex2D(_ThicknessMap, i.uv);
                refringenceColor *= (1.0 - thicknessMap.r);
                finalColor += refringenceColor;

                

                #ifdef USING_DIRECTIONAL_LIGHT
                    float atten = 1.0;
                #else
                    UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos); //
                #endif 
                finalColor *= atten;
                
                return float4(finalColor,1);
            }
            ENDCG
        }
        
        Pass
        {
            Tags {"LightMode" = "ForwardAdd"} //ForwardAdd
            Blend One One

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdadd //#pragma multi_compile_fwdadd 

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
                float3 normal : TEXCOORD1;
                float3 worldPos:TEXCOORD2;
                UNITY_SHADOW_COORDS(3)
            };

            sampler2D _MainTex;
            sampler2D _ThicknessMap;

            float4 _MainTex_ST;
            float4 _MainTexColor;
            samplerCUBE _CubeMap;
            float4 _CubeMap_HDR;
            float _RefringencePower;
            float _TranslucentPower;
            float _TranslucentInst;
            float _SkyLightPower;
            float _HighLightMapRotate;
            float _HighLightPower;

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                UNITY_TRANSFER_SHADOW(o, v.uv);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {

                float3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                float3 normal = normalize(i.normal);

                #ifdef USING_DIRECTIONAL_LIGHT
                    float3 light_dir = normalize(_WorldSpaceLightPos0);
                #else
                    float3 light_dir = normalize(_WorldSpaceLightPos0 - i.worldPos);
                #endif 

                float3 finalColor;
                //漫反射
                float NLDot = max(0, dot(light_dir, normal));
                float4 mainTex = tex2D(_MainTex, i.uv);
                float3 diffuseColor = mainTex * NLDot * _MainTexColor * _LightColor0;
                finalColor = diffuseColor;

                //SkyLight
                float SkyDot = dot(float3(0, 1, 0), normal) * 0.5 + 1;

                float3 skycolor = mainTex * SkyDot * _MainTexColor * _LightColor0 * _SkyLightPower;
                //finalColor += skycolor;

                //环境Cube
                float3 reflect_dir = reflect(-view_dir, normal);
                float theta = _HighLightMapRotate * UNITY_PI;
                float2x2 m_rot = float2x2(cos(theta), -sin(theta), sin(theta), cos(theta));
                float2 dir_rot = mul(m_rot, reflect_dir.zx);
                reflect_dir = float3(dir_rot.x, dir_rot.y, dir_rot.y);
                float4 env_color = texCUBE(_CubeMap, reflect_dir);
                float3 env_decode_color = DecodeHDR(env_color, _CubeMap_HDR);
                //fresenl
                float fresenl = 1.0 - max(0, dot(view_dir, normal));
                env_decode_color = env_decode_color * fresenl * _HighLightPower;
                //finalColor += env_decode_color;

                //透光效果
                //光线折射
                float3 refringenceDir = -normalize(light_dir + normal * _RefringencePower);
                float VLDot = max(0, dot(view_dir, refringenceDir));
                VLDot = pow(VLDot, _TranslucentPower) * _TranslucentInst;
                float3 refringenceColor = VLDot * _MainTexColor * mainTex * _LightColor0;
                float4 thicknessMap = tex2D(_ThicknessMap, i.uv);
                refringenceColor *= (1.0 - thicknessMap.r);
                finalColor += refringenceColor;

                #ifdef USING_DIRECTIONAL_LIGHT
                    float atten = 1.0;
                #else
                    UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos); //
                #endif 
                finalColor *= atten;

                return float4(finalColor,1);
            }
            ENDCG
        }
    }
}
