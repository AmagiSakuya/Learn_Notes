Shader "Learn/SK_Mannequin_Teleport"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalMap("NormalMap", 2D) = "bump" {}

        _TeleportProgress("TeleportProgress",Float) = 0.0
        _TeleportProgressSmooth("TeleportProgressSmooth",Range(0.0,1.0)) = 0.1

        [HDR] _TeleportColor("_TeleportColor",Color) = (1.0,1.0,1.0,1.0)
        _DissloveAreaOffset("DissloveAreaOffset",Range(-1.0,1.0)) = 0.0
        _DissloveAreaPow("DissloveAreaPow",Float) = 1.0

        _VertexOffset("VertexOffset",Float) = 0.0
        _VertexSmooth("VertexSmooth",Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
        LOD 100

        Pass
        {
            Tags {"LightMode" = "ForwardBase"} //ForwardAdd
            ZWrite On
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
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 world_pos:TEXCOORD1;
                float3 world_normal:TEXCOORD2;
                float4 world_tangent : TEXCOORD3;
                LIGHTING_COORDS(4, 5)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NormalMap;
            float _TeleportProgress;
            float _TeleportProgressSmooth;
            float4 _TeleportColor;
            float _DissloveAreaOffset;
            float _DissloveAreaPow;
            float _VertexOffset;
            float _VertexSmooth;

            float remap(float minOld, float maxOld, float minNew, float maxNew,float inputValue) {
                return  (minNew + (inputValue - minOld) * (maxNew - minNew) / (maxOld - minOld));
            }

            float3 mod3D289(float3 x) { return x - floor(x / 289.0) * 289.0; }

            float4 mod3D289(float4 x) { return x - floor(x / 289.0) * 289.0; }

            float4 permute(float4 x) { return mod3D289((x * 34.0 + 1.0) * x); }

            float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - r * 0.85373472095314; }

            float snoise(float3 v)
            {
                const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
                float3 i = floor(v + dot(v, C.yyy));
                float3 x0 = v - i + dot(i, C.xxx);
                float3 g = step(x0.yzx, x0.xyz);
                float3 l = 1.0 - g;
                float3 i1 = min(g.xyz, l.zxy);
                float3 i2 = max(g.xyz, l.zxy);
                float3 x1 = x0 - i1 + C.xxx;
                float3 x2 = x0 - i2 + C.yyy;
                float3 x3 = x0 - 0.5;
                i = mod3D289(i);
                float4 p = permute(permute(permute(i.z + float4(0.0, i1.z, i2.z, 1.0)) + i.y + float4(0.0, i1.y, i2.y, 1.0)) + i.x + float4(0.0, i1.x, i2.x, 1.0));
                float4 j = p - 49.0 * floor(p / 49.0);  // mod(p,7*7)
                float4 x_ = floor(j / 7.0);
                float4 y_ = floor(j - 7.0 * x_);  // mod(j,N)
                float4 x = (x_ * 2.0 + 0.5) / 7.0 - 1.0;
                float4 y = (y_ * 2.0 + 0.5) / 7.0 - 1.0;
                float4 h = 1.0 - abs(x) - abs(y);
                float4 b0 = float4(x.xy, y.xy);
                float4 b1 = float4(x.zw, y.zw);
                float4 s0 = floor(b0) * 2.0 + 1.0;
                float4 s1 = floor(b1) * 2.0 + 1.0;
                float4 sh = -step(h, 0.0);
                float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
                float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
                float3 g0 = float3(a0.xy, h.x);
                float3 g1 = float3(a0.zw, h.y);
                float3 g2 = float3(a1.xy, h.z);
                float3 g3 = float3(a1.zw, h.w);
                float4 norm = taylorInvSqrt(float4(dot(g0, g0), dot(g1, g1), dot(g2, g2), dot(g3, g3)));
                g0 *= norm.x;
                g1 *= norm.y;
                g2 *= norm.z;
                g3 *= norm.w;
                float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
                m = m * m;
                m = m * m;
                float4 px = float4(dot(x0, g0), dot(x1, g1), dot(x2, g2), dot(x3, g3));
                return 42.0 * dot(m, px);
            }

            v2f vert (appdata v)
            {
                v2f o;
                float3 world_pos = mul(unity_ObjectToWorld, v.vertex);
                float3 world_origin = mul(unity_ObjectToWorld, float3(0,0,0));
                float3 calc = max(0.0,((world_pos - world_origin).y +_TeleportProgress - _VertexOffset) / _VertexSmooth) ;
                //在物体空间下偏移顶点
                v.vertex.x += mul(unity_WorldToObject, calc * 2.0);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.world_pos = mul(unity_ObjectToWorld, v.vertex);
                o.world_normal = UnityObjectToWorldNormal(v.normal);
                o.world_tangent = normalize(mul(unity_ObjectToWorld, v.tangent));
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                //简单光照
                float3 view_dir = normalize(_WorldSpaceCameraPos - i.world_pos);
                float3 binormal = cross(i.world_normal, i.world_tangent.xyz) * i.world_tangent.w;
                float3x3 TBN = float3x3(normalize(i.world_tangent.xyz), normalize(binormal), normalize(i.world_normal));
                float3 view_tangentSpace = normalize(mul(TBN,view_dir));
                #ifdef USING_DIRECTIONAL_LIGHT
                float3 light_dir = normalize(_WorldSpaceLightPos0);
                #else
                float3 light_dir = normalize(_WorldSpaceLightPos0 - i.world_pos);
                #endif 
                float atten =  LIGHT_ATTENUATION(i);
                float4 mainTexColor = tex2D(_MainTex, i.uv);

                //法线贴图
                float4 normalMap = tex2D(_NormalMap, i.uv); 
                float3 normal_data = UnpackNormal(normalMap);
                float3 world_normal = normalize(i.world_tangent * normal_data.x  + binormal * normal_data.y + i.world_normal * normal_data.z);
                float lightModel = max(0.0, dot(light_dir, world_normal));
                float3 diffuse = mainTexColor.rgb * lightModel * _LightColor0.rgb * atten;
                
                //snoise
                float noise3D3 = snoise(i.world_pos.xxx * 200.0);
                noise3D3 = noise3D3 * 0.5 + 0.5;

                //传送消融
                float obj_pos_distance = mul(unity_WorldToObject, i.world_pos).x - _TeleportProgress;
                float obj_pos_distance_smooth = obj_pos_distance / _TeleportProgressSmooth;
                float opactiy = clamp (2.0 * obj_pos_distance_smooth - noise3D3, 0.0, 1.0);

                //传送颜色
                float dissloveArea = pow( 1.0 - distance(obj_pos_distance_smooth, _DissloveAreaOffset) , _DissloveAreaPow) - noise3D3;

                float3 dissloveColor = clamp(dissloveArea,0.0,1.0) * _TeleportColor;

                diffuse += dissloveColor;

                return float4(diffuse, opactiy);
            }
            ENDCG
        }
    
        Pass
        {
            Tags {"LightMode" = "ForwardAdd"} //ForwardAdd
            ZWrite On
            Blend SrcAlpha OneMinusSrcAlpha
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
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 world_pos:TEXCOORD1;
                float3 world_normal:TEXCOORD2;
                float4 world_tangent : TEXCOORD3;
                LIGHTING_COORDS(4, 5)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NormalMap;
            float _TeleportProgress;
            float _TeleportProgressSmooth;
            float4 _TeleportColor;
            float _DissloveAreaOffset;
            float _DissloveAreaPow;
            float _VertexOffset;
            float _VertexSmooth;

            float remap(float minOld, float maxOld, float minNew, float maxNew,float inputValue) {
                return  (minNew + (inputValue - minOld) * (maxNew - minNew) / (maxOld - minOld));
            }

            float3 mod3D289(float3 x) { return x - floor(x / 289.0) * 289.0; }

            float4 mod3D289(float4 x) { return x - floor(x / 289.0) * 289.0; }

            float4 permute(float4 x) { return mod3D289((x * 34.0 + 1.0) * x); }

            float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - r * 0.85373472095314; }

            float snoise(float3 v)
            {
                const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
                float3 i = floor(v + dot(v, C.yyy));
                float3 x0 = v - i + dot(i, C.xxx);
                float3 g = step(x0.yzx, x0.xyz);
                float3 l = 1.0 - g;
                float3 i1 = min(g.xyz, l.zxy);
                float3 i2 = max(g.xyz, l.zxy);
                float3 x1 = x0 - i1 + C.xxx;
                float3 x2 = x0 - i2 + C.yyy;
                float3 x3 = x0 - 0.5;
                i = mod3D289(i);
                float4 p = permute(permute(permute(i.z + float4(0.0, i1.z, i2.z, 1.0)) + i.y + float4(0.0, i1.y, i2.y, 1.0)) + i.x + float4(0.0, i1.x, i2.x, 1.0));
                float4 j = p - 49.0 * floor(p / 49.0);  // mod(p,7*7)
                float4 x_ = floor(j / 7.0);
                float4 y_ = floor(j - 7.0 * x_);  // mod(j,N)
                float4 x = (x_ * 2.0 + 0.5) / 7.0 - 1.0;
                float4 y = (y_ * 2.0 + 0.5) / 7.0 - 1.0;
                float4 h = 1.0 - abs(x) - abs(y);
                float4 b0 = float4(x.xy, y.xy);
                float4 b1 = float4(x.zw, y.zw);
                float4 s0 = floor(b0) * 2.0 + 1.0;
                float4 s1 = floor(b1) * 2.0 + 1.0;
                float4 sh = -step(h, 0.0);
                float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
                float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
                float3 g0 = float3(a0.xy, h.x);
                float3 g1 = float3(a0.zw, h.y);
                float3 g2 = float3(a1.xy, h.z);
                float3 g3 = float3(a1.zw, h.w);
                float4 norm = taylorInvSqrt(float4(dot(g0, g0), dot(g1, g1), dot(g2, g2), dot(g3, g3)));
                g0 *= norm.x;
                g1 *= norm.y;
                g2 *= norm.z;
                g3 *= norm.w;
                float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
                m = m * m;
                m = m * m;
                float4 px = float4(dot(x0, g0), dot(x1, g1), dot(x2, g2), dot(x3, g3));
                return 42.0 * dot(m, px);
            }

            v2f vert(appdata v)
            {
                v2f o;
                float3 world_pos = mul(unity_ObjectToWorld, v.vertex);
                float3 world_origin = mul(unity_ObjectToWorld, float3(0,0,0));
                float3 calc = max(0.0,((world_pos - world_origin).y + _TeleportProgress - _VertexOffset) / _VertexSmooth);
                //在物体空间下偏移顶点
                v.vertex.x += mul(unity_WorldToObject, calc * 2.0);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.world_pos = mul(unity_ObjectToWorld, v.vertex);
                o.world_normal = UnityObjectToWorldNormal(v.normal);
                o.world_tangent = normalize(mul(unity_ObjectToWorld, v.tangent));
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                //简单光照
                float3 view_dir = normalize(_WorldSpaceCameraPos - i.world_pos);
                float3 binormal = cross(i.world_normal, i.world_tangent.xyz) * i.world_tangent.w;
                float3x3 TBN = float3x3(normalize(i.world_tangent.xyz), normalize(binormal), normalize(i.world_normal));
                float3 view_tangentSpace = normalize(mul(TBN,view_dir));
                #ifdef USING_DIRECTIONAL_LIGHT
                float3 light_dir = normalize(_WorldSpaceLightPos0);
                #else
                float3 light_dir = normalize(_WorldSpaceLightPos0 - i.world_pos);
                #endif 
                float atten = LIGHT_ATTENUATION(i);
                float4 mainTexColor = tex2D(_MainTex, i.uv);

                //法线贴图
                float4 normalMap = tex2D(_NormalMap, i.uv);
                float3 normal_data = UnpackNormal(normalMap);
                float3 world_normal = normalize(i.world_tangent * normal_data.x + binormal * normal_data.y + i.world_normal * normal_data.z);
                float lightModel = max(0.0, dot(light_dir, world_normal));
                float3 diffuse = mainTexColor.rgb * lightModel * _LightColor0.rgb * atten;

                //snoise
                float noise3D3 = snoise(i.world_pos.xxx * 200.0);
                noise3D3 = noise3D3 * 0.5 + 0.5;

                //传送消融
                float obj_pos_distance = mul(unity_WorldToObject, i.world_pos).x - _TeleportProgress;
                float obj_pos_distance_smooth = obj_pos_distance / _TeleportProgressSmooth;
                float opactiy = clamp(2.0 * obj_pos_distance_smooth - noise3D3, 0.0, 1.0);

                //传送颜色
                float dissloveArea = pow(1.0 - distance(obj_pos_distance_smooth, _DissloveAreaOffset) , _DissloveAreaPow) - noise3D3;

                float3 dissloveColor = clamp(dissloveArea,0.0,1.0) * _TeleportColor;

                diffuse += dissloveColor;

                return float4(diffuse, opactiy);
            }
            ENDCG
        }
    }
}
