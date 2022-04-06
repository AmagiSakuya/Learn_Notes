Shader "Learn/ForwardRenderPathLight"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_NormalMap("NormalMap", 2D) = "bump" {}
		_NormalInensity("NormalInensity",Range(0,1.0)) = 1.0
		_SpecMaskMap("SpecMask", 2D) = "white" {}
		_Shininess("Shininess",Range(0.01,100)) = 1.0
		_SpecInensity("SpecInensity",Range(0.01,5)) = 1.0
		_AOMap("AOMap", 2D) = "white" {}
		_ParallaxMap("ParallaxMap", 2D) = "white" {} // 视差贴图
		_ParallaxInensity("ParallaxInensity",Range(-5.0,5.0)) = 0.0
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
				float4 tangent : TEXCOORD3;
				UNITY_SHADOW_COORDS(4)
				float4 worldPos:TEXCOORD5;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _NormalMap;
			float _NormalInensity;
			sampler2D _AOMap;
			sampler2D _SpecMaskMap;
			float _SpecInensity;
			sampler2D _ParallaxMap;
			float _ParallaxInensity;

			float _Shininess;

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

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = UnityObjectToWorldNormal(v.normal); // normalize(mul(v.normal, unity_WorldToObject));
				o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent));
				UNITY_TRANSFER_SHADOW(o, o.uv);
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float3 worldPos = i.worldPos;
				float3 view_dir = normalize(_WorldSpaceCameraPos - worldPos);
				float3 light_dir = normalize(_WorldSpaceLightPos0);

				float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w;

				//tex2D和for循环很影响性能
				float3x3 TBN = float3x3(normalize(i.tangent.xyz), normalize(binormal), normalize(i.normal));
				float3 view_tangentSpace = normalize(mul(TBN,view_dir));

				//高度贴图(uv 偏移)
				float2 uv_parallax = i.uv;
				uv_parallax = OffsetUVByHeightMap(_ParallaxMap, view_tangentSpace, _ParallaxInensity, uv_parallax);

				//法线贴图计算
				float4 normalMap = tex2D(_NormalMap, uv_parallax);
				float3 normal_data = UnpackNormal(normalMap);
				float3 normal = normalize(i.tangent * normal_data.x * _NormalInensity + binormal * normal_data.y * _NormalInensity + i.normal * normal_data.z);

				float3 finalColor;
				//漫反射
				float lightModel = max(0, dot(light_dir, normal));
				float4 mainTex = tex2D(_MainTex, uv_parallax);
				//mainTex = pow (mainTex,2.2);
				float3 diffuse = mainTex * lightModel;
				finalColor = diffuse * _LightColor0.rgb;
				//获取环境光颜色
				float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
				finalColor += ambient;
				//高光
				float4 speceMaskMap = tex2D(_SpecMaskMap, uv_parallax);
				//Phong 模型 耗性能
				//float3 reflect_dir = reflect(-light_dir, normal);
				//float3 spec_color = max(0, dot(reflect_dir, view_dir));
				//Blinn-phong 模型
				float3 reflect_dir = normalize(light_dir + view_dir);
				float3 spec_color = max(0, dot(reflect_dir, normal));
				spec_color = pow(spec_color, _Shininess) * _SpecInensity * speceMaskMap.rgb;
				finalColor += spec_color * _LightColor0.rgb;
				//阴影与光线衰减
				UNITY_LIGHT_ATTENUATION(atten, i, worldPos);
				finalColor = finalColor * atten;
				//环境光遮蔽
				float4 aoMap = tex2D(_AOMap,uv_parallax);
				finalColor = finalColor * aoMap.rgb;

				//高动态范围
				//finalColor = ACESFilm(finalColor);
				//finalColor = pow(finalColor , 1.0 /2.2);

				return float4(finalColor.rgb ,1.0);
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
				float4 tangent : TEXCOORD3;
				UNITY_SHADOW_COORDS(4)
				float4 worldPos:TEXCOORD5;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _NormalMap;
			float _NormalInensity;
			sampler2D _AOMap;
			sampler2D _SpecMaskMap;
			float _SpecInensity;
			sampler2D _ParallaxMap;
			float _ParallaxInensity;

			float _Shininess;

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

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = UnityObjectToWorldNormal(v.normal); // normalize(mul(v.normal, unity_WorldToObject));
				o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent));
				UNITY_TRANSFER_SHADOW(o, o.uv);
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float3 worldPos = i.worldPos;
				float3 view_dir = normalize(_WorldSpaceCameraPos - worldPos);
				//float3 light_dir = normalize(_WorldSpaceLightPos0 - worldPos);

				//_WorldSpaceLightPos0.w
				#ifdef USING_DIRECTIONAL_LIGHT
					float3 light_dir = normalize(_WorldSpaceLightPos0.xyz);
				#else
					float3 light_dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
				#endif

				float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w;

				//tex2D和for循环很影响性能
				float3x3 TBN = float3x3(normalize(i.tangent.xyz), normalize(binormal), normalize(i.normal));
				float3 view_tangentSpace = normalize(mul(TBN,view_dir));

				//高度贴图(uv 偏移)
				float2 uv_parallax = i.uv;
				uv_parallax = OffsetUVByHeightMap(_ParallaxMap, view_tangentSpace, _ParallaxInensity, uv_parallax);

				//法线贴图计算
				float4 normalMap = tex2D(_NormalMap, uv_parallax);
				float3 normal_data = UnpackNormal(normalMap);
				float3 normal = normalize(i.tangent * normal_data.x * _NormalInensity + binormal * normal_data.y * _NormalInensity + i.normal * normal_data.z);

				float3 finalColor;
				//漫反射
				float lightModel = max(0, dot(light_dir, normal));
				float4 mainTex = tex2D(_MainTex, uv_parallax);
				//mainTex = pow (mainTex,2.2);
				float3 diffuse = mainTex * lightModel;
				finalColor = diffuse * _LightColor0.rgb;
				//高光
				float4 speceMaskMap = tex2D(_SpecMaskMap, uv_parallax);
				//Phong 模型 耗性能
				//float3 reflect_dir = reflect(-light_dir, normal);
				//float3 spec_color = max(0, dot(reflect_dir, view_dir));
				//Blinn-phong 模型
				float3 reflect_dir = normalize(light_dir + view_dir);
				float3 spec_color = max(0, dot(reflect_dir, normal));
				spec_color = pow(spec_color, _Shininess) * _SpecInensity * speceMaskMap.rgb;
				finalColor += spec_color * _LightColor0.rgb;
				//阴影与光线衰减
				UNITY_LIGHT_ATTENUATION(atten, i, worldPos);
				finalColor = finalColor * atten;
				//环境光遮蔽
				float4 aoMap = tex2D(_AOMap,uv_parallax);
				finalColor = finalColor * aoMap.rgb;

				//高动态范围
				//finalColor = ACESFilm(finalColor);
				//finalColor = pow(finalColor , 1.0 /2.2);

				return float4(finalColor.rgb ,1.0);
			}
			ENDCG
		}

	}
	Fallback "Diffuse"
}