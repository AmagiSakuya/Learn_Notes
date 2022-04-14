Shader "Learn/BlinPhong_Standard"
{
	Properties
	{
		[Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 2
		[Header(Base Color)]
		[Space]
		_MainTex("Albedo", 2D) = "white" {} 
		_Color("AlbedoColor", Color) = (1.0,1.0,1.0,1.0)
		_NormalMap("Normal", 2D) = "bump" {}
		_NormalStrength("NormalStrength",Range(-1.0,1.0)) = 1.0
		_MetalMap("MetallicMap", 2D) = "black" {} 
		_MetalMapOffset("MetallicMapOffset",Range(-1.0,1.0)) = 0.0
		_MetalMapStrength("MetallicMapStrength",Range(0.0,10.0)) = 1.0
		_ParallaxMap("HeightMap", 2D) = "white" {}
		_ParallaxInensity("HeightMapStrength",Range(-5.0,5.0)) = 0.0
		[Header(Direct Specular)]
		[Space]
		_SpecMaskMap("SpecMask", 2D) = "white" {}
		_SpecMaskOffset("SpecMaskOffset",Range(-1.0,1.0)) = 0.0
		_SpecInensity("SpecBrightness",Range(0.0,10.0)) = 1.0
		_SpecRange("SpecRange",Range(0,1.0)) = 0.0
		[Header(InDirect Diffuse)]
		[Space]
		_AmbientInensity("AmbientInensity",Range(0,1.0)) = 0.0
		_AOMap("AOMap", 2D) = "white" {}
		_AOMapOffset("AOMapOffset",Range(-1.0,1.0)) = 0.0
		_AOBrightness("AOBrightness",Range(0.0,10.0)) = 1.0
		[Header(InDirect Specular)]
		[Space]
		_Roughness("RoughnessMap",2D) = "black" {}
		_RoughnessOffset("RoughnessMapOffset",Range(-1.0,1.0)) = 0.0
		_RoughnessBrightness("RoughnessMapStrength",Range(0.0,10.0)) = 1.0
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
			Cull [_Cull]
			Tags {"LightMode" = "ForwardBase"} //ForwardAdd
			//Blend One One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fwdbase //#pragma multi_compile_fwdadd 

			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _Color;
			sampler2D _NormalMap;
			float _NormalStrength;
			sampler2D _MetalMap;
			float _MetalMapOffset;
			float _MetalMapStrength;
			sampler2D _SpecMaskMap;
			float _SpecMaskOffset;
			float _SpecInensity;
			float _SpecRange;
			sampler2D _ParallaxMap;
			float _ParallaxInensity;
			float _AmbientInensity;
			sampler2D _Roughness;
			float _RoughnessOffset;
			float _RoughnessBrightness;
			sampler2D _AOMap;
			float _AOMapOffset;
			float _AOBrightness;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;//main texture uv
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float2 uv_light : TEXCOORD1;//light map texture uv
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float4 tangent : TEXCOORD2;
				float4 worldPos:TEXCOORD3;
				UNITY_SHADOW_COORDS(4)
				float3  SHLighting : COLOR;
			};

			struct fragCalcData
			{
				float3 worldPos;
				float3 view_dir;
				float3 binormal;
				float3x3 TBN;
				float3 view_tangentSpace;
				float3 light_dir;
				float2 uv_parallax;
				float3 normal;
			};

			//高动态范围
			float3 ACESFilm(float3 x) {
				float a = 2.51f;
				float b = 0.03f;
				float c = 2.43f;
				float d = 0.59f;
				float e = 0.14f;
				return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
			}

			//高度置换
			float2 OffsetUVByHeightMap(sampler2D _ParallaxMap, float3 view_tangentSpace, float _ParallaxInensity, float2 uv_parallax) {
				float4 heightMap = tex2D(_ParallaxMap, uv_parallax);
				return uv_parallax - (1.0 - heightMap) * (view_tangentSpace.xy / view_tangentSpace.z) * _ParallaxInensity * 0.01;
			}

			//实时直接漫反射
			float3 RealTimeDirectDiffuseCalc(float3 mainTex ,fragCalcData data) {
				float lightModel = max(0.0, dot(data.light_dir, data.normal));
				//mainTex = pow (mainTex,2.2);
				float3 diffuse = mainTex.rgb * lightModel * _Color;
				return diffuse * _LightColor0.rgb;
			}

			//实时直接镜面反射(高光)
			float3 ReatimeDirectSpecCalc(float4 speceMaskMap,fragCalcData data) {
				//Phong 模型 耗性能
				//float3 reflect_dir = reflect(-light_dir, normal);
				//float3 spec_color = max(0, dot(reflect_dir, view_dir));
				//Blinn-phong 模型
				float3 reflect_dir = normalize(data.light_dir + data.view_dir);
				float3 spec_color_model = max(0.0, dot(reflect_dir, data.normal));
				spec_color_model = pow(spec_color_model, 100.0 - _SpecRange * 100.0) ;
				float3 m_speceMaskMap = saturate(speceMaskMap + _SpecMaskOffset) * _SpecInensity;
				return	m_speceMaskMap * spec_color_model * _LightColor0;
			}

			//实时间接镜面反射（反射探针）
			float3 ReatimeInDirectSpecCalc(fragCalcData data) {
				float4 roughness = tex2D(_Roughness, data.uv_parallax);
				roughness = saturate(roughness + _RoughnessOffset) * _RoughnessBrightness;
				float3 m_reflect = reflect(-data.view_dir, data.normal);
				float miplevel = roughness * 6.0;
				//float4 env_color = texCUBE(_EnvCubeMap, m_reflect );
				//float3 env_decode_color = DecodeHDR(env_color, _EnvCubeMap_HDR);
				
				float4 env_color = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, m_reflect, miplevel);
				float3 env_decode_color = DecodeHDR(env_color, unity_SpecCube0_HDR);		
				return env_decode_color;
			}

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = (v.uv_light.xy * unity_LightmapST.xy + unity_LightmapST.zw);
				o.normal = UnityObjectToWorldNormal(v.normal); // normalize(mul(v.normal, unity_WorldToObject));
				o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent));
				o.SHLighting = ShadeSH9(float4(o.normal, 1));
				UNITY_TRANSFER_SHADOW(o, o.uv);
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				fragCalcData data;
				data.worldPos = i.worldPos;
				data.view_dir = normalize(_WorldSpaceCameraPos - data.worldPos);
				data.binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w;
				data.TBN = float3x3(normalize(i.tangent.xyz), normalize(data.binormal), normalize(i.normal));
				data.view_tangentSpace = normalize(mul(data.TBN,data.view_dir));
				//float3 light_dir = normalize(_WorldSpaceLightPos0);
				#ifdef USING_DIRECTIONAL_LIGHT
					data.light_dir = normalize(_WorldSpaceLightPos0);
				#else
					data.light_dir = normalize(_WorldSpaceLightPos0 - data.worldPos);
				#endif 

				//高度贴图_uv偏移
				float2 uv_parallax = i.uv;
				uv_parallax = OffsetUVByHeightMap(_ParallaxMap, data.view_tangentSpace, _ParallaxInensity, uv_parallax);
				data.uv_parallax = uv_parallax;

				//贴图采样
				float3 mainTex = tex2D(_MainTex, data.uv_parallax);
				float4 speceMaskMap = tex2D(_SpecMaskMap, data.uv_parallax);
				float4 normalMap = tex2D(_NormalMap, data.uv_parallax); //法线贴图
				float3 normal_data = UnpackNormal(normalMap);
				data.normal = normalize(i.tangent * normal_data.x * _NormalStrength + data.binormal * normal_data.y * _NormalStrength + i.normal * normal_data.z);

				float3 finalColor;

				float3 direct_diffuse = float3(0,0,0);
				float3 direct_spec = float3(0,0,0);
				float3 indirect_diffuse = float3(0,0,0);
				float3 indirect_spec = float3(0,0,0);
				float m_atten = 1.0;
				//LightMap烘培判断
				#if defined(LIGHTMAP_ON) && defined(SHADOWS_SHADOWMASK) //MixedLight
					float3 c_lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw));
					direct_diffuse = RealTimeDirectDiffuseCalc(mainTex,data); //直接漫反射_实时
					direct_spec = ReatimeDirectSpecCalc(speceMaskMap,data); //直接高光_实时
					UNITY_LIGHT_ATTENUATION(atten, i, data.worldPos); //阴影与光线衰减_实时
					m_atten = atten;
					//间接漫反射_烘培
					indirect_diffuse = c_lm * mainTex * _Color;

				#elif defined(LIGHTMAP_ON) && !defined(SHADOWS_SHADOWMASK) //BakedLight
					float3 c_lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw));
					//直接漫反射+间接漫反射+阴影与光线衰减_烘培
					direct_diffuse = c_lm * mainTex * _Color;
				#elif defined(LIGHTMAP_OFF) //realtime light
					direct_diffuse = RealTimeDirectDiffuseCalc(mainTex,data); //直接漫反射_实时
					direct_spec = ReatimeDirectSpecCalc(speceMaskMap,data); //直接高光_实时
					UNITY_LIGHT_ATTENUATION(atten, i, data.worldPos);
					m_atten = atten;
					float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
					indirect_diffuse = (ambient +  i.SHLighting) * _AmbientInensity * mainTex; //间接漫反射
				#endif
				//间接镜面反射
				indirect_spec = ReatimeInDirectSpecCalc(data);
				//金属度
				float4 _MetalMexTex = tex2D(_MetalMap,data.uv_parallax);
				float metalValue = saturate(_MetalMexTex + _MetalMapOffset) * _MetalMapStrength;	
				//环境光遮蔽贴图
				float4 aoMap = tex2D(_AOMap,data.uv_parallax);
				float aoValue= saturate(aoMap + _AOMapOffset) * _AOBrightness;	

				float3 not_metal = (direct_diffuse * aoValue + direct_spec ) * m_atten  + indirect_diffuse;
				float3 is_metal =  direct_spec * m_atten + indirect_spec;

				finalColor = lerp(not_metal,is_metal,metalValue);

				//高动态范围
				//finalColor = ACESFilm(finalColor);
				//finalColor = pow(finalColor , 1.0 /2.2);
				
				return float4(finalColor , 1.0);
			}
			ENDCG
		}

		
		Pass
		{
			Cull [_Cull]
			Tags {"LightMode" = "ForwardAdd"} //ForwardAdd
			Blend One One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fwdadd //#pragma multi_compile_fwdadd 

			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _Color;
			sampler2D _NormalMap;
			float _NormalStrength;
			sampler2D _MetalMap;
			float _MetalMapOffset;
			float _MetalMapStrength;


			sampler2D _SpecMaskMap;
			float _SpecMaskOffset;
			float _SpecInensity;
			float _SpecRange;

			sampler2D _ParallaxMap;
			float _ParallaxInensity;
			float _AmbientInensity;
			//samplerCUBE _EnvCubeMap;
			//float4 _EnvCubeMap_HDR;

			sampler2D _Roughness;
			float _RoughnessOffset;
			float _RoughnessBrightness;
			sampler2D _AOMap;
			float _AOMapOffset;
			float _AOBrightness;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;//main texture uv
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float2 uv_light : TEXCOORD1;//light map texture uv
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float4 tangent : TEXCOORD2;
				float4 worldPos:TEXCOORD3;
				UNITY_SHADOW_COORDS(4)
				float3  SHLighting : COLOR;
			};

			struct fragCalcData
			{
				float3 worldPos;
				float3 view_dir;
				float3 binormal;
				float3x3 TBN;
				float3 view_tangentSpace;
				float3 light_dir;
				float2 uv_parallax;
				float3 normal;
			};

			//高动态范围
			float3 ACESFilm(float3 x) {
				float a = 2.51f;
				float b = 0.03f;
				float c = 2.43f;
				float d = 0.59f;
				float e = 0.14f;
				return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
			}

			//高度置换
			float2 OffsetUVByHeightMap(sampler2D _ParallaxMap, float3 view_tangentSpace, float _ParallaxInensity, float2 uv_parallax) {
				float4 heightMap = tex2D(_ParallaxMap, uv_parallax);
				return uv_parallax - (1.0 - heightMap) * (view_tangentSpace.xy / view_tangentSpace.z) * _ParallaxInensity * 0.01;
			}

			//实时直接漫反射
			float3 RealTimeDirectDiffuseCalc(float3 mainTex ,fragCalcData data) {
				float lightModel = max(0.0, dot(data.light_dir, data.normal));
				//mainTex = pow (mainTex,2.2);
				float3 diffuse = mainTex.rgb * lightModel * _Color;
				return diffuse * _LightColor0.rgb;
			}

			//实时直接镜面反射(高光)
			float3 ReatimeDirectSpecCalc(float4 speceMaskMap,fragCalcData data) {
				//Phong 模型 耗性能
				//float3 reflect_dir = reflect(-light_dir, normal);
				//float3 spec_color = max(0, dot(reflect_dir, view_dir));
				//Blinn-phong 模型
				float3 reflect_dir = normalize(data.light_dir + data.view_dir);
				float3 spec_color_model = max(0.0, dot(reflect_dir, data.normal));
				spec_color_model = pow(spec_color_model, 100.0 - _SpecRange * 100.0) ;
				float3 m_speceMaskMap = saturate(speceMaskMap + _SpecMaskOffset) * _SpecInensity;
				return	m_speceMaskMap * spec_color_model * _LightColor0;
			}

			//实时间接镜面反射（反射探针）
			float3 ReatimeInDirectSpecCalc(fragCalcData data) {
				float4 roughness = tex2D(_Roughness, data.uv_parallax);
				roughness = saturate(roughness + _RoughnessOffset) * _RoughnessBrightness;
				float3 m_reflect = reflect(-data.view_dir, data.normal);
				float miplevel = roughness * 6.0;
				//float4 env_color = texCUBE(_EnvCubeMap, m_reflect );
				//float3 env_decode_color = DecodeHDR(env_color, _EnvCubeMap_HDR);
				
				float4 env_color = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, m_reflect, miplevel);
				float3 env_decode_color = DecodeHDR(env_color, unity_SpecCube0_HDR);		
				return env_decode_color;
			}

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = (v.uv_light.xy * unity_LightmapST.xy + unity_LightmapST.zw);
				o.normal = UnityObjectToWorldNormal(v.normal); // normalize(mul(v.normal, unity_WorldToObject));
				o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent));
				o.SHLighting = ShadeSH9(float4(o.normal, 1));
				UNITY_TRANSFER_SHADOW(o, o.uv);
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				fragCalcData data;
				data.worldPos = i.worldPos;
				data.view_dir = normalize(_WorldSpaceCameraPos - data.worldPos);
				data.binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w;
				data.TBN = float3x3(normalize(i.tangent.xyz), normalize(data.binormal), normalize(i.normal));
				data.view_tangentSpace = normalize(mul(data.TBN,data.view_dir));
				//float3 light_dir = normalize(_WorldSpaceLightPos0);
				#ifdef USING_DIRECTIONAL_LIGHT
					data.light_dir = normalize(_WorldSpaceLightPos0);
				#else
					data.light_dir = normalize(_WorldSpaceLightPos0 - data.worldPos);
				#endif 

				//高度贴图_uv偏移
				float2 uv_parallax = i.uv;
				uv_parallax = OffsetUVByHeightMap(_ParallaxMap, data.view_tangentSpace, _ParallaxInensity, uv_parallax);
				data.uv_parallax = uv_parallax;

				//贴图采样
				float3 mainTex = tex2D(_MainTex, data.uv_parallax);
				float4 speceMaskMap = tex2D(_SpecMaskMap, data.uv_parallax);
				float4 normalMap = tex2D(_NormalMap, data.uv_parallax); //法线贴图
				float3 normal_data = UnpackNormal(normalMap);
				data.normal = normalize(i.tangent * normal_data.x * _NormalStrength + data.binormal * normal_data.y * _NormalStrength + i.normal * normal_data.z);

				float3 finalColor;

				float3 direct_diffuse = float3(0,0,0);
				float3 direct_spec = float3(0,0,0);

				float3 indirect_spec = float3(0,0,0);
				float m_atten = 1.0;
				//LightMap烘培判断
				#if defined(LIGHTMAP_ON) && defined(SHADOWS_SHADOWMASK) //MixedLight
					float3 c_lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw));
					direct_diffuse = RealTimeDirectDiffuseCalc(mainTex,data); //直接漫反射_实时
					direct_spec = ReatimeDirectSpecCalc(speceMaskMap,data); //直接高光_实时
					UNITY_LIGHT_ATTENUATION(atten, i, data.worldPos); //阴影与光线衰减_实时
					m_atten = atten;
				#elif defined(LIGHTMAP_ON) && !defined(SHADOWS_SHADOWMASK) //BakedLight
					float3 c_lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw));
					//直接漫反射+间接漫反射+阴影与光线衰减_烘培
					direct_diffuse = c_lm * mainTex * _Color;
				#elif defined(LIGHTMAP_OFF) //realtime light
					direct_diffuse = RealTimeDirectDiffuseCalc(mainTex,data); //直接漫反射_实时
					direct_spec = ReatimeDirectSpecCalc(speceMaskMap,data); //直接高光_实时
					UNITY_LIGHT_ATTENUATION(atten, i, data.worldPos);
					m_atten = atten;
				#endif
				//间接镜面反射
				indirect_spec = ReatimeInDirectSpecCalc(data);
				//金属度
				float4 _MetalMexTex = tex2D(_MetalMap,data.uv_parallax);
				float metalValue = saturate(_MetalMexTex + _MetalMapOffset) * _MetalMapStrength;	
				//环境光遮蔽贴图
				float4 aoMap = tex2D(_AOMap,data.uv_parallax);
				float aoValue= saturate(aoMap + _AOMapOffset) * _AOBrightness;	

				float3 not_metal = (direct_diffuse * aoValue + direct_spec ) * m_atten ;
				float3 is_metal =  direct_spec * m_atten + indirect_spec;

				finalColor = lerp(not_metal,is_metal,metalValue);

				//高动态范围
				//finalColor = ACESFilm(finalColor);
				//finalColor = pow(finalColor , 1.0 /2.2);
				
				return float4(finalColor , 1.0);
			}
			ENDCG
		}

		Pass
		{
			Name "Meta"
			Tags {"LightMode" = "Meta"}
			Cull Off

			CGPROGRAM
			#pragma vertex vert_meta
			#pragma fragment frag_meta

			#include "Lighting.cginc"
			#include "UnityMetaPass.cginc"

			struct v2f
			{
				float4 pos:SV_POSITION;
				float2 uv:TEXCOORD1;
				float3 worldPos:TEXCOORD0;
			};

			uniform fixed4 _Color;
			uniform sampler2D _MainTex;
			v2f vert_meta(appdata_full v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f,o);
				o.pos = UnityMetaVertexPosition(v.vertex,v.texcoord1.xy,v.texcoord2.xy,unity_LightmapST,unity_DynamicLightmapST);
				o.uv = v.texcoord.xy;
				return o;
			}

			fixed4 frag_meta(v2f IN) :SV_Target
			{
				UnityMetaInput metaIN;
				UNITY_INITIALIZE_OUTPUT(UnityMetaInput,metaIN);
				metaIN.Albedo = tex2D(_MainTex,IN.uv).rgb * _Color.rgb;
				metaIN.Emission = 0;
				return UnityMetaFragment(metaIN);
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
}