Shader "Learn/HoudiniVAT_SimpleDissolve"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalMap("Normal", 2D) = "bump" {}
        _NormalStrength("NormalStrength",Range(-1.0,1.0)) = 1.0
        _RoughnessMap("Roughness", 2D) = "black" {}
        _SpecSmooth("SpecSmooth",Range(0.01,100.0)) = 1.0
        _SpecInensity("SpecInensity",Range(0.01,100.0)) = 1.0
        _AmbientInensity("AmbientInensity",Range(0,1.0)) = 0.0
        _AOMap("AOMap", 2D) = "white" {}

        [Header(VAT)]
        [Space]
        _boundingMax("Bounding Max", Float) = 1.072085
        _boundingMin("Bounding Min", Float) = -2.653735
        _numOfFrames("Number Of Frames", int) = 100
        _speed("Speed", Float) = 0.33
        [MaterialToggle] _pack_normal ("Pack Normal", Float) = 0
        _posTex ("Position Map (RGB)", 2D) = "white" {}
        _nTex ("Normal Map (RGB)", 2D) = "grey" {}

        [Header(Dissolve)]
        [Space]
        _zeroStart("zeroStart",Float) = 0.0
        _DissolveNoise ("DissolveNoise", 2D) = "white" {}
        _dissolve("_dissolve",Range(0,1.0)) = 0.0
        [HDR]_DissolveColor ("DissolveColor", Color) = (0,0,0,1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" }
        LOD 100

        Pass
        {
            Tags {"LightMode" = "ForwardBase"} //ForwardAdd
            Blend SrcAlpha OneMinusSrcAlpha
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
                float2 texcoord1 : TEXCOORD1;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal : TEXCOORD1;
                float3 world_pos:TEXCOORD2;
                float4 tangent : TEXCOORD3;
                UNITY_SHADOW_COORDS(4)
                float3  SHLighting : COLOR;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NormalMap;
            float _NormalStrength;
            sampler2D _RoughnessMap;
            float _SpecSmooth;
            float _SpecInensity;
            float _AmbientInensity;
            sampler2D _AOMap;

            sampler2D _posTex;
            sampler2D _nTex;
            
            uniform float _boundingMax;
            uniform float _boundingMin;
            uniform float _speed;
            uniform int _numOfFrames;
            
            sampler2D _DissolveNoise;
            float _zeroStart;
            float _dissolve;
            float4 _DissolveColor;

            v2f vert (appdata v)
            {
                v2f o;
                //Houdini顶点动画
                float timeInFrames = ((ceil(frac(-_Time.y * _speed) * _numOfFrames))/_numOfFrames) + (1.0/_numOfFrames);
                float4 texturePos = tex2Dlod(_posTex,float4(v.texcoord1.x, (timeInFrames + v.texcoord1.y), 0, 0));
                float expand = _boundingMax - _boundingMin;
                texturePos.xyz *= expand;
                texturePos.xyz += _boundingMin;
                texturePos.x *= -1;  //flipped to account for right-handedness of unity
                v.vertex.xyz += texturePos.xzy;  //swizzle y and z because textures are exported with z-up


                o.pos = UnityObjectToClipPos(v.vertex);
                o.world_pos = mul(unity_ObjectToWorld, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent));
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.SHLighting = ShadeSH9(float4(o.normal, 1));
                
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                //光照计算
                float3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.world_pos);
                UNITY_LIGHT_ATTENUATION(atten, i, i.world_pos);

                float3 binormal = normalize(cross(i.normal, i.tangent.xyz) * i.tangent.w);
                float3x3 TBN = float3x3(normalize(i.tangent.xyz), normalize(binormal), normalize(i.normal));
                float3 view_tangentSpace = normalize(mul(TBN, view_dir));

                float4 normalMap = tex2D(_NormalMap, i.uv); //法线贴图
                float3 normal_data = UnpackNormal(normalMap);
                float3 normal = normalize(i.tangent * normal_data.x * _NormalStrength + binormal * normal_data.y * _NormalStrength + i.normal * normal_data.z);

                #ifdef USING_DIRECTIONAL_LIGHT
                    float3 light_dir = normalize(_WorldSpaceLightPos0);
                #else
                    float3 light_dir = normalize(_WorldSpaceLightPos0 - i.world_pos);
                #endif 

                float3 finalColor = float3(0,0,0);

                //Map
                float4 albedo = tex2D(_MainTex, i.uv);
                float roughness = tex2D(_RoughnessMap, i.uv).r;
                
                //区分金属部分
                float3 base_metal_color = lerp(0, albedo, roughness);

                float diffuse_term = max(0.0,dot(light_dir, normal));
                float3 directDiffuse = albedo * diffuse_term * atten * _LightColor0.rgb;
                finalColor += directDiffuse;
                //直接高光
                float3 blin_reflect_dir = normalize(light_dir + view_dir);
                float NdotR = dot(normal, blin_reflect_dir);
                float smoothness = 1.0 - roughness;
                float shininess = lerp(1, _SpecSmooth, smoothness);
                float3 spec_color_model = pow(max(0.0, NdotR), shininess * smoothness);
                float3 directSpec = base_metal_color * spec_color_model * _LightColor0 * _SpecInensity;
                finalColor += directSpec;
                
                //间接漫反射
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
                float3 indirect_diffuse = (ambient +  i.SHLighting) * _AmbientInensity * albedo; 
                finalColor += indirect_diffuse;

                //实时间接镜面反射（反射探针）
                float3 m_reflect = reflect(-view_dir, normal);
                float miplevel = roughness * 6.0;
                float4 env_color = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, m_reflect, miplevel);
                float3 env_decode_color = DecodeHDR(env_color, unity_SpecCube0_HDR);		
                finalColor+=indirect_diffuse;
                float4 aoMap = tex2D(_AOMap, i.uv);
                finalColor *=aoMap;

                //溶解
                float3 ObjTransformToWorld = mul(unity_ObjectToWorld, float4( float3( 0,0,0 ), 1 ) ).xyz;
                float _dis = clamp(0,1,(i.world_pos.y - (ObjTransformToWorld.y + _zeroStart)));
                float dissolveNoise = tex2D(_DissolveNoise, i.uv).r; 
                dissolveNoise = smoothstep(dissolveNoise , dissolveNoise - _dissolve ,_dis);
                //dissolveNoise = step(_dissolve, dissolveNoise);
                float opacity = 1 - dissolveNoise;
                float4 dissolveColor = _DissolveColor * dissolveNoise;
                finalColor += dissolveColor;
                return float4(finalColor,opacity);
            }
            ENDCG
        }
    }
}
