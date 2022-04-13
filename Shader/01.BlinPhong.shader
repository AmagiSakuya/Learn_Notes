Shader "Learn/BlinPhong"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_NormalMap("NormalMap", 2D) = "bump" {}
		_NormalInensity("NormalInensity",Range(-1.0,1.0)) = 1.0
		_SpecMaskMap("SpecMask", 2D) = "white" {}
		_Shininess("Shininess",Range(0.01,100)) = 1.0
		_SpecInensity("SpecInensity",Range(0.01,5)) = 1.0
		_AOMap("AOMap", 2D) = "white" {}
		_ParallaxMap("ParallaxMap", 2D) = "white" {} // 视差贴图
		_ParallaxInensity("ParallaxInensity",Range(-5.0,5.0)) = 0.0
		_AmbientInensity("AmbientInensity",Range(0,1.0)) = 0.0
		_Reflectivity("Reflectivity",Range(0,1.0)) = 0.0
		_Roughness("RoughnessMap",2D) = "black" {}
		_RoughnessContrast("RoughnessContrast",Range(0.0,10.0)) = 1.0
		_RoughnessBrightness("RoughnessBrightness",Range(0.0,10.0)) = 1.0
		_RoughnessMin("RoughnessMin",Float) = 0.0
		_RoughnessMax("RoughnessMax",Float) = 1.0
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
			Cull Off
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
			float _NormalInensity;
			sampler2D _AOMap;
			sampler2D _SpecMaskMap;
			float _SpecInensity;
			sampler2D _ParallaxMap;
			float _ParallaxInensity;
			float _AmbientInensity;
			float _Shininess;
			float _Reflectivity;
			sampler2D _Roughness;
			float _RoughnessContrast;
			float _RoughnessBrightness;
			float _RoughnessMin;
			float _RoughnessMax;

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
				float4 uv : TEXCOORD0; //x
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
				float lightModel = max(0, dot(data.light_dir, data.normal));
				//mainTex = pow (mainTex,2.2);
				float3 diffuse = mainTex * lightModel * _Color;
				return diffuse * _LightColor0.rgb;
			}

			//实时直接镜面反射(高光)
			float3 ReatimeDirectSpecCalc(float4 speceMaskMap,fragCalcData data) {
				//Phong 模型 耗性能
				//float3 reflect_dir = reflect(-light_dir, normal);
				//float3 spec_color = max(0, dot(reflect_dir, view_dir));
				//Blinn-phong 模型
				float3 reflect_dir = normalize(data.light_dir + data.view_dir);
				float3 spec_color = max(0, dot(reflect_dir, data.normal));
				spec_color = pow(spec_color, _Shininess) * _SpecInensity * speceMaskMap.rgb;
				return spec_color * _LightColor0.rgb;
			}

			//实时间接镜面反射（反射探针）
			float3 ReatimeInDirectSpecCalc(float4 speceMaskMap,fragCalcData data) {
				float4 roughness = tex2D(_Roughness, data.uv_parallax);
				roughness = saturate(pow(roughness, _RoughnessContrast) * _RoughnessBrightness);
				roughness = lerp(_RoughnessMin, _RoughnessMax, roughness);
				roughness = roughness * (1.7 - 0.7 * roughness);
				float miplevel = roughness * 9.0;

				float4 env_color = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflect(-data.view_dir, data.normal) , roughness);
				return DecodeHDR(env_color, unity_SpecCube0_HDR);

				//float4 env_color = texCube(_CubeMap, reflect(-view_dir, normal));
				//float3 env_decode_color = DecodeHDR(env_color, _CubeMap_HDR);
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
				data.normal = normalize(i.tangent * normal_data.x * _NormalInensity + data.binormal * normal_data.y * _NormalInensity + i.normal * normal_data.z);

				float3 finalColor;

				//LightMap烘培判断
				#if defined(LIGHTMAP_ON) && defined(SHADOWS_SHADOWMASK) //MixedLight
					float3 c_lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw));
					finalColor = RealTimeDirectDiffuseCalc(mainTex,data); //直接漫反射_实时
					//直接高光_实时
					finalColor += ReatimeDirectSpecCalc(speceMaskMap,data);
					//阴影与光线衰减_实时
					UNITY_LIGHT_ATTENUATION(atten, i, data.worldPos);
					finalColor *= atten;
					//间接漫反射_烘培
					finalColor += c_lm * mainTex * _Color;

				#elif defined(LIGHTMAP_ON) && !defined(SHADOWS_SHADOWMASK) //BakedLight
					float3 c_lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw));
					//直接漫反射+间接漫反射+阴影与光线衰减_烘培
					finalColor = c_lm * mainTex * _Color;
				#elif defined(LIGHTMAP_OFF) //realtime light
					finalColor = RealTimeDirectDiffuseCalc(mainTex,data); //直接漫反射_实时
					//直接高光_实时
					finalColor += ReatimeDirectSpecCalc(speceMaskMap,data);
					//阴影与光线衰减_实时
					UNITY_LIGHT_ATTENUATION(atten, i, data.worldPos);
					finalColor *= atten;
					//间接漫反射_环境光_实时
					float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
					finalColor += ambient * _AmbientInensity;
					//间接漫反射_SH间接光_实时
					finalColor += i.SHLighting * mainTex * _Color;

				#endif

				//环境光遮蔽贴图
				float4 aoMap = tex2D(_AOMap,data.uv_parallax);
				finalColor *= aoMap.rgb;
				//间接镜面反射_实时
				finalColor = lerp(finalColor, ReatimeInDirectSpecCalc(speceMaskMap,data) * aoMap, _Reflectivity);

				//高动态范围
				//finalColor = ACESFilm(finalColor);
				//finalColor = pow(finalColor , 1.0 /2.2);
				//finalColor = lerp(finalColor, env_decode_color* speceMaskMap * aoMap, _Reflectivity);

				return float4(finalColor.rgb, 1.0);
			}
			ENDCG
		}

		Pass
		{
			Cull Off
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
			sampler2D _NormalMap;
			float _NormalInensity;
			sampler2D _AOMap;
			sampler2D _SpecMaskMap;
			float _SpecInensity;
			sampler2D _ParallaxMap;
			float _ParallaxInensity;
			float _AmbientInensity;
			float _Shininess;
			float _Reflectivity;
			float _Roughness;

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
				float lightModel = max(0, dot(data.light_dir, data.normal));
				//mainTex = pow (mainTex,2.2);
				float3 diffuse = mainTex * lightModel;
				return diffuse * _LightColor0.rgb;
			}

			//实时直接镜面反射
			float3 ReatimeDirectSpecCalc(float4 speceMaskMap,fragCalcData data) {
				//Phong 模型 耗性能
				//float3 reflect_dir = reflect(-light_dir, normal);
				//float3 spec_color = max(0, dot(reflect_dir, view_dir));
				//Blinn-phong 模型
				float3 reflect_dir = normalize(data.light_dir + data.view_dir);
				float3 spec_color = max(0, dot(reflect_dir, data.normal));
				spec_color = pow(spec_color, _Shininess) * _SpecInensity * speceMaskMap.rgb;
				return spec_color * _LightColor0.rgb;
			}

			//实时间接镜面反射（反射探针）
			float3 ReatimeInDirectSpecCalc(float4 speceMaskMap,fragCalcData data) {
				float4 env_color = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflect(-data.view_dir, data.normal) , _Roughness);
				return DecodeHDR(env_color, unity_SpecCube0_HDR);
				//float4 env_color = texCube(_CubeMap, reflect(-view_dir, normal));
				//float3 env_decode_color = DecodeHDR(env_color, _CubeMap_HDR);
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
				data.normal = normalize(i.tangent * normal_data.x * _NormalInensity + data.binormal * normal_data.y * _NormalInensity + i.normal * normal_data.z);

				float3 finalColor;

				//LightMap烘培判断
				#if defined(LIGHTMAP_ON) && defined(SHADOWS_SHADOWMASK) //MixedLight
					float3 c_lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw));
					finalColor = RealTimeDirectDiffuseCalc(mainTex,data); //直接漫反射_实时
					//直接高光_实时
					finalColor += ReatimeDirectSpecCalc(speceMaskMap,data);
					//阴影与光线衰减_实时
					UNITY_LIGHT_ATTENUATION(atten, i, data.worldPos);
					finalColor *= atten;
					//间接漫反射_烘培
					finalColor += c_lm * mainTex;

				#elif defined(LIGHTMAP_ON) && !defined(SHADOWS_SHADOWMASK) //BakedLight
					float3 c_lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw));
					//直接漫反射+间接漫反射+阴影与光线衰减_烘培
					finalColor = c_lm * mainTex;

				#elif defined(LIGHTMAP_OFF) //realtime light
					finalColor = RealTimeDirectDiffuseCalc(mainTex,data); //直接漫反射_实时
					//直接高光_实时
					finalColor += ReatimeDirectSpecCalc(speceMaskMap,data);
					//阴影与光线衰减_实时
					UNITY_LIGHT_ATTENUATION(atten, i, data.worldPos);
					finalColor *= atten;

				#endif

				//环境光遮蔽贴图
				float4 aoMap = tex2D(_AOMap,data.uv_parallax);
				finalColor *= aoMap.rgb;

				return float4(finalColor.rgb, 1.0);
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