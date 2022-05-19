Shader "Learn/Shield"
{
	Properties
	{
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 2
		[Toggle] _Debug("Debug",Float) = 0
		_HintPosition("HintPosition",Vector) = (0,0,0,0)
		_HintScale("HintScale",Float) = 0
		_HintSmooth("HintSmooth",Range(0.01,10.0)) = 0.5
		_HintRamp("HintRamp",2D) = "white" {}
		_HintNoise("HintNoise",2D) = "black" {}
		_HintNoisePower("HintNoisePower",Float) = 1.0
		_FadeMaskDistance("FadeMaskDistance",Float)  = 1.0
		_FadeMaskPower("FadeMaskPower",Float) = 1.0
		[Space(10)]
		_FlowLight("FlowLight",2D) = "white" {}
		_FlowMap("FlowMap", 2D) = "white" {}
		_Size("Size", Range( 0 , 10)) = 1
		_FlowDirection("FlowDirection", Vector) = (0,0,0,0)
		_FlowStrength("FlowStrength", Vector) = (1,1,0,0)
		_FlowSpeed("FlowSpeed", Float) = 0.2
		_Fresnel("Fresnel", Vector) = (0,1,5,0)
		_DepthFadeDistance("DepthFadeDistance", Float) = 1.0
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
	}

	SubShader
	{
		Tags{ "RenderType" = "Transparent"  "Queue" = "Transparent" }
		Cull [_Cull]
		ZWrite Off
		CGPROGRAM
		#include "UnityCG.cginc"
		#pragma target 3.0
		#pragma surface surf BlinnPhong vertex:vert alpha:fade keepalpha noshadow 

		//UNITY_DECLARE_DEPTH_TEXTURE( _CameraDepthTexture );
		//uniform float4 _CameraDepthTexture_TexelSize;
		sampler2D _CameraDepthTexture;
		uniform float _DepthFadeDistance;

		float _Debug;
		float4 _HintPositions[20];
		float _HintScales[20];
		float4 _HintPosition;
		float _HintScale;
		float _HintSmooth;
		sampler2D _HintRamp;
		sampler2D _HintNoise;
		float _HintNoisePower;
		float _FadeMaskDistance;
		float _FadeMaskPower;

		sampler2D _FlowLight;
		uniform float4 _FlowLight_ST;
		uniform sampler2D _FlowMap;
		uniform float _Size;
		uniform float2 _FlowDirection;
		uniform float2 _FlowStrength;
		uniform float _FlowSpeed;

		float3 _Fresnel;

		struct Input
		{
			float2 uv_HintNoise;
			float2 uv2_MainTex;
			float3 worldPos;
			float3 viewDir;
			float3 worldNormal;
			float4 proj;
		};

		float HitColor(Input IN,float3 HintPositions,float3 HintScales){
			float3 m_distance = distance(IN.worldPos ,HintPositions);
			float3 distance_base = m_distance - (HintScales - 1.0); 
			float3 distance_base_reserve = 1.0 - distance_base;
			float hintNoise = tex2D(_HintNoise, IN.uv_HintNoise).r;
			float noise_distance = distance_base_reserve + hintNoise * _HintNoisePower;
			float3 distance_model = noise_distance / _HintSmooth;
			distance_model = clamp(distance_model,0.0,1.0);
			float hintRamp = tex2D(_HintRamp,float2(distance_model.x,0.5)).r;
			float mask = 1.0 - clamp((m_distance * _FadeMaskPower ) / _FadeMaskDistance,0.0,1.0);
			return hintRamp * mask;
		}

		float HitColorByIndex(Input IN, float index){
			return HitColor(IN,_HintPositions[index],_HintScales[index]);
		}

		float HitRampArr(Input IN){
			float hintRamp = 0.0;
			for(int i = 0; i < 20 ; i++){
				hintRamp += HitColorByIndex(IN,i);
			}
			return hintRamp;
		}
		
		float3 FlowMap(float2 uv){
			float2 uv_Flowmap = uv * _FlowLight_ST.xy + _FlowLight_ST.zw;
			uv_Flowmap = (( uv_Flowmap / _Size )).xy;
			float2 flow_Direction = ( (tex2D( _FlowMap, uv )).rg + 0.5 );
			float flow_Distance = _Time.y * _FlowSpeed;
			float frac_flow_Distance = frac( flow_Distance );
			float2 m_uv1 = ( uv_Flowmap + ( flow_Direction * _FlowStrength * frac_flow_Distance ) );
			float2 m_uv2 = ( uv_Flowmap + ( flow_Direction * _FlowStrength * frac( ( flow_Distance + 0.5 ) ) ) );
			float4 result = lerp( tex2D( _FlowLight, m_uv1 ) , tex2D( _FlowLight, m_uv2 ) , ( abs( ( frac_flow_Distance - 0.5 ) ) / 0.5 ));
			return result.rgb;
		}


		 void vert (inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.proj = ComputeScreenPos(UnityObjectToClipPos(v.vertex));
            COMPUTE_EYEDEPTH(o.proj.z);
        }

		void surf(Input IN , inout SurfaceOutput o )
		{
			float hintRamp = 0.0;
			//���������
			hintRamp = _Debug==0 ? HitRampArr(IN) : HitColor(IN,_HintPosition,_HintScale);
			//flowMap
			float3 flowMap = FlowMap(IN.uv2_MainTex);
			//fresnel
			float NdotV =  dot( IN.viewDir ,IN.worldNormal) ;
			float3 m_normal = (((NdotV>0)?(IN.worldNormal):(-IN.worldNormal)));
			float fresnel =  ( _Fresnel.x + _Fresnel.y * pow( max( 1.0 - dot( IN.viewDir ,m_normal) , 0.0001 ), _Fresnel.z ) );
			//使用投影纹理采样
			float m_depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(IN.proj)).r);
            float distance = (1.0 - (m_depth - IN.proj.z));
			float powDistance = saturate(max(0.001,pow(distance,_DepthFadeDistance)));
			fresnel += powDistance;
			
			o.Emission = flowMap + fresnel + hintRamp;
			o.Alpha = clamp(flowMap * fresnel + hintRamp ,0.0,1.0);

			//o.Emission = powDistance.xxx;
			//o.Alpha = 1.0;
		}

		ENDCG
	}
	Fallback "Diffuse"
}