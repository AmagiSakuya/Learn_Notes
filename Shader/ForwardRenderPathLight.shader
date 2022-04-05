/*
# 前向渲染光照模型

## 前向渲染
前向渲染的特点为需要两个Pass：
1.每个物体调用ForwardBase的Pass渲染平行光
2.每个物体调用ForwardAdd的Pass渲染所有光
两个pass采用Blend One One的形式混合

当光源数量超出质量设定里的数量 将采用顶点光模式渲染
增加光强或者更改important可以设定重要程度

*/

Shader "Learn/ForwardRenderPathLight"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_NormalMap("NormalMap", 2D) = "bump" {}
		_NormalInensity("NormalInensity",Range(0,1.0)) = 1.0
		_ParallaxMap("ParallaxMap", 2D) = "white" {} // 视差贴图
		_ParallaxInensity("ParallaxInensity",Range(-5.0,5.0)) = 0.0
		_AOMap("AOMap", 2D) = "white" {}
		_SpecMaskMap("SpecMask", 2D) = "white" {}
		_Shininess("Shininess",Range(0.01,100)) = 1.0
		_SpecInensity("SpecInensity",Range(0.01,5)) = 1.0
		_AmbientColor("AmbientColor",Color) = (0,0,0,1)
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
			Cull Off
			Tags {"LightMode" = "ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			/*ForwardBase所必须的引用*/
			#pragma multi_compile_fwdbase

			#include "UnityCG.cginc"

			float3 ACESFilm(float3 x){
				float a = 2.51f;
                float b = 0.03f;
                float c = 2.43f;
                float d = 0.59f;
                float e = 0.14f;
                return saturate((x*(a*x + b)) / (x*(c*x + d) + e));
			}

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 normal : TEXCOORD1;
				float3 pos : TEXCOORD2;
				float3 tangent : TEXCOORD3;
				float3 binormal : TEXCOORD4;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _NormalMap;
			float _SpecInensity;
			float _NormalInensity;
			float _ParallaxInensity;
			sampler2D _AOMap;
			sampler2D _SpecMaskMap;
			sampler2D _ParallaxMap;
			//float4 _AOMap_ST;

			//光源颜色
			float4 _LightColor0;
			float _Shininess;
			float3 _AmbientColor;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = mul(v.normal, unity_WorldToObject);
				o.tangent = mul(unity_ObjectToWorld,v.tangent);
				o.binormal = cross(o.normal ,o.tangent) * v.tangent.w;
				o.pos = mul(unity_ObjectToWorld, v.vertex) ;
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				//tex2D和for循环很影响性能

				float3x3 TBN = float3x3(i.tangent, i.binormal, i.normal);
				
				float3 view_dir = normalize(_WorldSpaceCameraPos - i.pos);
				float3 view_tangentSpace = normalize(mul(TBN,view_dir)) ;
				float2 uv_parallax = i.uv;
				float j = 0;
				for(j = 0; j<10 ;j++){
					float4 heightMap = tex2D(_ParallaxMap, uv_parallax);
					uv_parallax = uv_parallax - (1.0 - heightMap) * (view_tangentSpace.xy / view_tangentSpace.z) *_ParallaxInensity *0.01;
				}
				
				float4 mainTex = tex2D(_MainTex, uv_parallax);
				//mainTex = pow (mainTex,2.2);
				float4 aoMap = tex2D(_AOMap,uv_parallax);
				
				float4 speceMaskMap = tex2D(_SpecMaskMap, uv_parallax);
				float4 normalMap = tex2D(_NormalMap, uv_parallax);
				float3 normal_data = UnpackNormal(normalMap);

				float3 light_dir = normalize(_WorldSpaceLightPos0);

				//法线贴图计算
				
				float3 normal = normalize( i.tangent * normal_data.x * _NormalInensity + i.binormal  * normal_data.y * _NormalInensity + i.normal * normal_data.z);
				//normal = normalize(mul(normal_data,TBN)) * _NormalInensity;


				float lightModel = max(0,dot(light_dir, normal));

				//漫反射
				float3 diffuse = mainTex * lightModel;

				//高光
				//Phong 模型 耗性能
				//float3 reflect_dir = reflect(-light_dir, normal);
				//float3 spec_color = max(0, dot(reflect_dir, view_dir));

				//Blin-phong 模型
				float3 reflect_dir = normalize(light_dir + view_dir);
				float3 spec_color = max(0, dot(reflect_dir, normal));
				spec_color = pow(spec_color, _Shininess) * _SpecInensity * speceMaskMap.rgb;

				float3 finalColor = (diffuse + spec_color ) * _LightColor0.xyz * aoMap.xyz;
				//finalColor = ACESFilm(finalColor);
				//finalColor = pow(finalColor , 1.0 /2.2);
				return float4(finalColor,1.0);	
			}
			ENDCG
		}
	
		//Pass
		//{
		//	Cull Off
		//	Tags {"LightMode" = "ForwardAdd"}
		//	Blend One One
		//	CGPROGRAM
		//	#pragma vertex vert
		//	#pragma fragment frag
		//	/*ForwardBase所必须的引用*/
		//	#pragma multi_compile_fwdadd

		//	#include "UnityCG.cginc"
		//	#include "AutoLight.cginc"

		//	struct appdata
		//	{
		//		float4 vertex : POSITION;
		//		float2 uv : TEXCOORD0;
		//		float3 normal : NORMAL;
		//		float4 tangent : TANGENT;
		//	};

		//	struct v2f
		//	{
		//		float2 uv : TEXCOORD0;
		//		float4 vertex : SV_POSITION;
		//		float3 normal : TEXCOORD1;
		//		float3 pos : TEXCOORD2;
		//		float3 tangent : TEXCOORD3;
		//		float3 binormal : TEXCOORD4;
		//	};

		//	sampler2D _MainTex;
		//	float4 _MainTex_ST;
		//	sampler2D _NormalMap;
		//	float _SpecInensity;
		//	float _NormalInensity;
		//	sampler2D _AOMap;
		//	sampler2D _SpecMaskMap;
		//	//float4 _AOMap_ST;

		//	//光源颜色
		//	float4 _LightColor0;
		//	float _Shininess;
		//	float3 _AmbientColor;

		//	//高动态范围
		//	float3 ACESFilm(float3 x){
		//		float a = 2.51f;
		//		float b = 0.03f;
		//		float c = 2.43f;
		//		float d = 0.59f;
		//		float e = 0.14f;
		//		return saturate((x*(a*x +b)) / (x * (c*x +d)+e));
		//	}

		//	v2f vert(appdata v)
		//	{
		//		v2f o;
		//		o.vertex = UnityObjectToClipPos(v.vertex);
		//		o.uv = TRANSFORM_TEX(v.uv, _MainTex);
		//		o.normal = normalize(mul(v.normal, unity_WorldToObject));
		//		o.tangent = normalize(mul(unity_ObjectToWorld,v.tangent));
		//		o.binormal = normalize(cross(o.normal ,o.tangent) * v.tangent.w);
		//		o.pos =  mul(unity_ObjectToWorld, v.vertex) ;
		//		return o;
		//	}

		//	float4 frag(v2f i) : SV_Target
		//	{
		//		float4 mainTex = tex2D(_MainTex, i.uv);
		//		float4 aoMap = tex2D(_AOMap, i.uv);
		//		float4 speceMaskMap = tex2D(_SpecMaskMap, i.uv);
		//		float4 normalMap = tex2D(_NormalMap, i.uv);
		//		float3 normal_data = UnpackNormal(normalMap);

		//		float3 normal = normalize(i.normal);
		//		float3 view_dir = normalize(_WorldSpaceCameraPos - i.pos);
		//		#if defined(DIRECTIONAL)
		//		float3 light_dir = normalize(_WorldSpaceLightPos0);
		//		float attention = 1.0;
		//		#elif defined(POINT)
		//		float3 light_dir = normalize(_WorldSpaceLightPos0 - i.pos);
		//		float distance = length(_WorldSpaceLightPos0 - i.pos);
		//		float range = 1.0 / unity_WorldToLight[0][0];
		//		float attention = saturate((range - distance)/range);
		//		#endif 
		
		//		//法线贴图计算
		//		normal =normalize( i.tangent * normal_data.x * _NormalInensity + i.binormal  * normal_data.y * _NormalInensity + normal * normal_data.z);

		//		//float lightModel = dot(light_dir, normal) * 0.5 + 0.5;
		//		float lightModel = max(0,dot(light_dir, normal));

		//		//漫反射
		//		float3 diffuse = mainTex * lightModel * attention ;

		//		//高光
		//		//Phong 模型 耗性能
		//		//float3 reflect_dir = reflect(-light_dir, normal);
		//		//biln-Phong模型
		//		float3 reflect_dir = normalize(light_dir + view_dir);

		//		float3 spec_color = max(0, dot(normal, reflect_dir));

		//		spec_color = pow(spec_color, _Shininess) * _SpecInensity * speceMaskMap.rgb;

		//		float3 finalColor = (diffuse + spec_color ) * _LightColor0.xyz * aoMap.xyz;
		
		//		return float4(finalColor,1);	
		//	}
		//	ENDCG
		//}

	}
}