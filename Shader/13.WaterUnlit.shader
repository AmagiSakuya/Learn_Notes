Shader "Unlit/WaterUnlit"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _ReflectionTex("ReflectionTex",2D) = "white"{}
        _WaterNormal("WaterNormal", 2D) = "bump" {}
        _WaterNormalInstensity("WaterNormalInstensity" , Range(0.0,10.0)) = 1.0
        _WaterSpeed("WaterSpeed",Vector) = (1.0,0.0,0.0,0.0)
        _UnderwaterTex("UnderwaterTex",2D) = "white"{}
        _UnderwaterHeight("UnderwaterHeight",Float) = 0.0
        _UnderwaterTexColor("UnderwaterTexColor", Color) = (1,1,1,1)
        _UnderwaterFresnel("UnderwaterFresnel",Vector) = (0.0,1.0,0.5,0.0)
        _SpecTint("SpecTint",Color) = (1,1,1,1)
        _SpecPower("SpecPower",Range(0.01,1.0)) = 0.5
        _SpecPowerInstensity("SpecPowerInstensity",Float) = 1.0
        _SpecStartEnd("SpecStartEnd",Vector) = (0.0,200.0,0.0,0.0)
        _BlinkThreshold("BlinkThreshold",Float) = 2.0
        _BlinkInstensity("BlinkInstensity",Float) = 5.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags {"LightMode" = "ForwardBase"} //ForwardAdd
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
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float4 worldPos : TEXCOORD3;
                float4 screenPos : TEXCOORD4;
            };

            uniform sampler2D _ReflectionTex;
            uniform float4 _ReflectionTex_ST;
            uniform float4 _Color;
            uniform sampler2D _WaterNormal;
            uniform float4 _WaterNormal_ST;
            uniform float2 _WaterSpeed;
            uniform float _WaterNormalInstensity;
            uniform sampler2D _UnderwaterTex;
            uniform float4 _UnderwaterTex_ST;
            uniform float _UnderwaterHeight;
            uniform float4 _UnderwaterTexColor;
            uniform float3 _UnderwaterFresnel;
            uniform float4 _SpecTint;
            uniform float _SpecPower;
            uniform float _SpecPowerInstensity;
            uniform float2 _SpecStartEnd;
            uniform float _BlinkThreshold;
            uniform float _BlinkInstensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.texcoord;
                o.normal = UnityObjectToWorldNormal(v.normal); 
                o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent));
                o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                float3 view_dir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w;
                float3x3 TBN = float3x3(normalize(i.tangent.xyz), normalize(binormal), normalize(i.normal));

                float2 screen_uv = i.screenPos.xy / i.screenPos.w;
                //screen_uv = (screen_uv + 1.0) * 0.5;
               
                //waterNormal偏移
                float2 uv_WaterNormal = i.uv * _WaterNormal_ST.xy + _WaterNormal_ST.zw;
                float2 waterUV = uv_WaterNormal + _Time.x * _WaterSpeed;
                float3 waterNormal = UnpackNormal(tex2D(_WaterNormal, waterUV));
                float2 waterUV2 = uv_WaterNormal + _Time.x * (-_WaterSpeed);
                float3 waterNormal2 = UnpackNormal(tex2D(_WaterNormal, waterUV2));
                waterNormal = BlendNormals(waterNormal, waterNormal2);
                //削弱视野远处waterNormal tilling值
                waterNormal.xy = waterNormal.xy / (i.pos.w + 1.0);
                float2 reflectUV = screen_uv + waterNormal.xy * _WaterNormalInstensity;
                
                float4 reflectionColor = tex2D(_ReflectionTex, reflectUV) * _Color;

                //高光
                #ifdef USING_DIRECTIONAL_LIGHT
                    float3 light_dir = normalize(_WorldSpaceLightPos0.xyz);
                #else
                    float3 light_dir = normalize(_WorldSpaceLightPos0 - i.worldPos);
                #endif 
                float3 blin_reflect_dir = normalize(light_dir + view_dir);
                float NdotR = max(0.0, dot(float3(waterNormal.x, waterNormal.z, waterNormal.y), blin_reflect_dir));
                float3 spec_color =  pow(NdotR, _SpecPower * 255) * _SpecTint * _SpecPowerInstensity;
                //Blink
                float2 reflectBlinkUV = screen_uv + waterNormal.xy * (_WaterNormalInstensity + _BlinkInstensity);
                float4 blinkColor = tex2D(_ReflectionTex, reflectBlinkUV) * _Color;
                blinkColor = max(0.0, blinkColor - _BlinkThreshold);
                //线性雾方式柔化远端
                float m_distance = distance(i.worldPos, _WorldSpaceCameraPos);
                float m_linefog = clamp((_SpecStartEnd.y - m_distance) / (_SpecStartEnd.y - _SpecStartEnd.x), 0.0, 1.0);
                spec_color = spec_color * m_linefog;
                //Underwater
                //高度
                float3 view_tangentSpace = normalize(mul(TBN, view_dir));
                float2 paralaxOffset = ParallaxOffset(0, _UnderwaterHeight, view_tangentSpace);
                float2 uv_parallax  = (i.uv * _UnderwaterTex_ST.xy + _UnderwaterTex_ST.zw) + paralaxOffset;
                float4 underwaterColor = tex2D(_UnderwaterTex, uv_parallax) * _UnderwaterTexColor;

                float underwaterFresnel = (_UnderwaterFresnel.x + _UnderwaterFresnel.y * pow(max(1.0 - dot(view_dir, i.normal), 0.0001), _UnderwaterFresnel.z));
                
                //混合水底贴图
                float3 finalColor = lerp(underwaterColor + spec_color + blinkColor, reflectionColor, underwaterFresnel);

                return float4(finalColor.xyz,1.0);
            }
            ENDCG
        }
    }
}
