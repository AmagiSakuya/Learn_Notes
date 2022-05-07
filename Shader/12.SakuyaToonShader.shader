Shader "Unlit/SakuyaToonShader"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Color("Color",Color) = (1.0,1.0,1.0,1.0)
        _ColorShadow("ColorShadow",Color) = (0.5,0.5,0.5,1.0)
        _ShadowSmooth("ShadowSmooth",Float) = 0.0
        _ShadowRange("ShadowRange",Float) = 0.5
        _SpecularColor("Specular Color", Color) = (1,1,1)
        _SpecularStrength("SpecularStrength", Range(0, 1)) = 0.4
        _SpecularGloss("Sprecular Gloss", Range(0.001, 20)) = 4.0
        _RimColor("_RimColor", Color) = (1,1,1,1)
        _RimBloomExp("RimBloomExp",Float) = 5.0
        _RimBloomStrength("RimBloomStrength",Float) = 1.0
        _RimAdjustOld("RimAdjustOld",Vector) = (0.0,1.0,1.0,1.0)
        _OutLineColor("OutLineColor", Color) = (0.0,0.0,0.0,1)
        _OutlineWidth("OutlineWidth",Float) = 0.0
    }
        SubShader
        {
            Tags { "RenderType" = "Opaque" }
            LOD 100

            //描边Pass
            Pass
            {
                Tags {"LightMode" = "ForwardBase"}

                Cull Front
                //ZWrite On

                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #include "UnityCG.cginc"

                half _OutlineWidth;
                half4 _OutLineColor;

                struct a2v
                {
                    float4 vertex : POSITION;
                    float3 normal : NORMAL;
                    float2 uv : TEXCOORD0;
                    float4 vertColor : COLOR;
                    float4 tangent : TANGENT;
                };

                struct v2f
                {
                    float4 pos : SV_POSITION;
                    float4 vertColor : TEXCOORD0;
                };


                v2f vert(a2v v)
                {
                    v2f o;
                    UNITY_INITIALIZE_OUTPUT(v2f, o);

                    //简单外扩
                    o.pos = UnityObjectToClipPos(float4(v.vertex.xyz + v.normal * _OutlineWidth * v.vertColor .a * 0.0001, 1));//顶点沿着法线方向外扩
                    o.vertColor = v.vertColor;

                    //修正摄像机距离问题
                    //float4 pos = UnityObjectToClipPos(v.vertex);
                    //float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal.xyz);
                    //float3 ndcNormal = normalize(TransformViewToProjection(viewNormal.xyz)) * pos.w;//将法线变换到NDC空间
                    //pos.xy += 0.01 * _OutlineWidth * ndcNormal.xy;
                    //o.pos = pos;
                    
                    
                    return o;
                }

                half4 frag(v2f i) : SV_TARGET
                {
                   // return float4(i.vertColor.rgb,1.0)
                    return _OutLineColor;
                }
                ENDCG
            }

            Pass
            {
                Tags {"LightMode" = "ForwardBase"} //ForwardAdd
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                #include "UnityCG.cginc"
                #include "AutoLight.cginc"
                #include "Lighting.cginc"

                #pragma multi_compile_fwdbase //#pragma multi_compile_fwdadd 

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
                    float4 worldPos:TEXCOORD2;
                };

                sampler2D _MainTex;
                float4 _MainTex_ST;
                float4 _Color;
                float4 _ColorShadow;
                float _ShadowSmooth;
                float _ShadowRange;

                float3 _SpecularColor;
                float _SpecularStrength;
                float _SpecularGloss;

                float4 _RimColor;
                float _RimBloomExp;
                float _RimBloomStrength;
                float4 _RimAdjustOld;

                v2f vert(appdata v)
                {
                    v2f o;
                    o.pos = UnityObjectToClipPos(v.vertex);
                    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                    o.normal = UnityObjectToWorldNormal(v.normal); // normalize(mul(v.normal, unity_WorldToObject));
                    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                    return o;
                }

                float4 frag(v2f i) : SV_Target
                {
                    float3 view_dir = normalize(_WorldSpaceCameraPos - i.worldPos);
                    float3 normal = normalize(i.normal);
                    #ifdef USING_DIRECTIONAL_LIGHT
                        float3 light_dir = normalize(_WorldSpaceLightPos0);
                    #else
                        float3 light_dir = normalize(_WorldSpaceLightPos0 - i.worldPos);
                    #endif 

                        //漫反射
                        float halfLambert = dot(i.normal,light_dir) * 0.5 + 0.5;
                        float ramp = smoothstep(0, _ShadowSmooth, halfLambert - _ShadowRange);
                        float3 diffuseColor = lerp(_ColorShadow, _Color, ramp);
                        float4 mainTexCol = tex2D(_MainTex, i.uv);
                        float3 baseColor = diffuseColor * mainTexCol * _LightColor0.rgb;
                        //高光
                        float3 halfDir = normalize(light_dir + view_dir);
                        float NdotH = max(0, dot(i.normal, halfDir));
                        float SpecularSize = pow(NdotH, _SpecularGloss) * _SpecularStrength;
                        float3 specular = SpecularSize * _SpecularColor * _LightColor0.rgb;
                        //边缘光
                        float f = 1.0 - saturate(dot(view_dir, i.normal));
                        //float rim = smoothstep(_RimAdjustOld.x, _RimAdjustOld.y, f);
                        //rim = smoothstep(0, _RimAdjustOld.z, rim);
                        //float3 rimColor = rim * _RimColor.rgb * _RimAdjustOld.a;

                        //边缘光2 让边缘光来自光照方向
                        float NdotL = max(0, dot(i.normal, light_dir));
                        float rimBloom = pow(f, _RimBloomExp) * _RimBloomStrength * NdotL;
                        float3 rimColor = rimBloom * _RimColor;

                        float3 final_color = baseColor + specular + rimColor;
                        return float4(final_color.rgb,1.0);
                    }
                    ENDCG
                }
        }
}
