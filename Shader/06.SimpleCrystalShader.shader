// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Learn/SimpleCrystal"
{
	Properties
	{
		_ReflectionTex("ReflectionTex", CUBE) = "white" {}
		_ReflectionTex2("ReflectionTex2", CUBE) = "white" {}
		_Color("Color", Color) = (1,1,1,0)
		_Normal("Normal", 2D) = "bump" {}
		_BackStrength("BackStrength", Float) = 1
		_FrontStrength("FrontStrength", Float) = 0
		_FresnelMaskBias("FresnelMaskBias", Float) = 0
		_FresnelMaskScale("FresnelMaskScale", Float) = 1
		_FresnelMaskPower("FresnelMaskPower", Float) = 1
		[HideInInspector] _texcoord( "", 2D ) = "white" {}

	}
	
	SubShader
	{
		
		
		Tags { "RenderType"="Opaque" "Queue"="Geometry" }
	LOD 100

		
		Pass
		{
			Name "First Pass"
			Tags { "LightMode"="ForwardBase" }
			Cull Front
			ZWrite On
			ZTest LEqual
			Blend One Zero

			CGPROGRAM

			

			#ifndef UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX
			//only defining to not throw compilation error over Unity 5.5
			#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
			#endif
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing
			#pragma multi_compile_fwdbase

			#include "UnityCG.cginc"
			#define ASE_NEEDS_FRAG_WORLD_POSITION


			struct appdata
			{
				float4 vertex : POSITION;
				float4 color : COLOR;
				float4 ase_texcoord : TEXCOORD0;
				float4 ase_tangent : TANGENT;
				float3 ase_normal : NORMAL;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			
			struct v2f
			{
				float4 vertex : SV_POSITION;
				#ifdef ASE_NEEDS_FRAG_WORLD_POSITION
				float3 worldPos : TEXCOORD0;
				#endif
				float4 ase_texcoord1 : TEXCOORD1;
				float4 ase_texcoord2 : TEXCOORD2;
				float4 ase_texcoord3 : TEXCOORD3;
				float4 ase_texcoord4 : TEXCOORD4;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			uniform samplerCUBE _ReflectionTex;
			uniform sampler2D _Normal;
			uniform float4 _Normal_ST;
			uniform samplerCUBE _ReflectionTex2;
			uniform float4 _Color;
			uniform float _BackStrength;

			
			v2f vert ( appdata v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

				float3 ase_worldTangent = UnityObjectToWorldDir(v.ase_tangent);
				o.ase_texcoord2.xyz = ase_worldTangent;
				float3 ase_worldNormal = UnityObjectToWorldNormal(v.ase_normal);
				o.ase_texcoord3.xyz = ase_worldNormal;
				float ase_vertexTangentSign = v.ase_tangent.w * unity_WorldTransformParams.w;
				float3 ase_worldBitangent = cross( ase_worldNormal, ase_worldTangent ) * ase_vertexTangentSign;
				o.ase_texcoord4.xyz = ase_worldBitangent;
				
				o.ase_texcoord1.xyz = v.ase_texcoord.xyz;
				
				//setting value to unused interpolator channels and avoid initialization warnings
				o.ase_texcoord1.w = 0;
				o.ase_texcoord2.w = 0;
				o.ase_texcoord3.w = 0;
				o.ase_texcoord4.w = 0;
				float3 vertexValue = float3(0, 0, 0);
				#if ASE_ABSOLUTE_VERTEX_POS
				vertexValue = v.vertex.xyz;
				#endif
				vertexValue = vertexValue;
				#if ASE_ABSOLUTE_VERTEX_POS
				v.vertex.xyz = vertexValue;
				#else
				v.vertex.xyz += vertexValue;
				#endif
				o.vertex = UnityObjectToClipPos(v.vertex);

				#ifdef ASE_NEEDS_FRAG_WORLD_POSITION
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				#endif
				return o;
			}
			
			fixed4 frag (v2f i ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
				fixed4 finalColor;
				#ifdef ASE_NEEDS_FRAG_WORLD_POSITION
				float3 WorldPosition = i.worldPos;
				#endif
				float2 uv_Normal = i.ase_texcoord1.xyz.xy * _Normal_ST.xy + _Normal_ST.zw;
				float3 ase_worldTangent = i.ase_texcoord2.xyz;
				float3 ase_worldNormal = i.ase_texcoord3.xyz;
				float3 ase_worldBitangent = i.ase_texcoord4.xyz;
				float3 tanToWorld0 = float3( ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x );
				float3 tanToWorld1 = float3( ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y );
				float3 tanToWorld2 = float3( ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z );
				float3 ase_worldViewDir = UnityWorldSpaceViewDir(WorldPosition);
				ase_worldViewDir = normalize(ase_worldViewDir);
				float3 worldRefl13 = reflect( -ase_worldViewDir, float3( dot( tanToWorld0, tex2D( _Normal, uv_Normal ).rgb ), dot( tanToWorld1, tex2D( _Normal, uv_Normal ).rgb ), dot( tanToWorld2, tex2D( _Normal, uv_Normal ).rgb ) ) );
				float3 WorldReflection25 = worldRefl13;
				float4 ReflectionTex0129 = texCUBE( _ReflectionTex, WorldReflection25 );
				float4 ReflectionTex231 = texCUBE( _ReflectionTex2, WorldReflection25 );
				float4 baseColor35 = ( ReflectionTex0129 * ReflectionTex231 * _Color * _BackStrength );
				
				
				finalColor = baseColor35;
				return finalColor;
			}
			ENDCG
		}
		
		
		Pass
		{
			Name "Second Pass"
			Tags { "LightMode"="ForwardBase" }
			Cull Back
			ZWrite On
			ZTest LEqual
			Blend One One

			CGPROGRAM

			

			#ifndef UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX
				//only defining to not throw compilation error over Unity 5.5
				#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
				#endif
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_instancing
				#pragma multi_compile_fwdadd

				#include "UnityCG.cginc"
				#define ASE_NEEDS_FRAG_WORLD_POSITION


				struct appdata
				{
					float4 vertex : POSITION;
					float4 color : COLOR;
					float4 ase_texcoord : TEXCOORD0;
					float4 ase_tangent : TANGENT;
					float3 ase_normal : NORMAL;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				struct v2f
				{
					float4 vertex : SV_POSITION;
					#ifdef ASE_NEEDS_FRAG_WORLD_POSITION
					float3 worldPos : TEXCOORD0;
					#endif
					float4 ase_texcoord1 : TEXCOORD1;
					float4 ase_texcoord2 : TEXCOORD2;
					float4 ase_texcoord3 : TEXCOORD3;
					float4 ase_texcoord4 : TEXCOORD4;
					UNITY_VERTEX_INPUT_INSTANCE_ID
					UNITY_VERTEX_OUTPUT_STEREO
				};

				uniform samplerCUBE _ReflectionTex2;
				uniform sampler2D _Normal;
				uniform float4 _Normal_ST;
				uniform float _FrontStrength;
				uniform float _FresnelMaskBias;
				uniform float _FresnelMaskScale;
				uniform float _FresnelMaskPower;


				v2f vert(appdata v )
				{
					v2f o;
					UNITY_SETUP_INSTANCE_ID(v);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
					UNITY_TRANSFER_INSTANCE_ID(v, o);

					float3 ase_worldTangent = UnityObjectToWorldDir(v.ase_tangent);
					o.ase_texcoord2.xyz = ase_worldTangent;
					float3 ase_worldNormal = UnityObjectToWorldNormal(v.ase_normal);
					o.ase_texcoord3.xyz = ase_worldNormal;
					float ase_vertexTangentSign = v.ase_tangent.w * unity_WorldTransformParams.w;
					float3 ase_worldBitangent = cross( ase_worldNormal, ase_worldTangent ) * ase_vertexTangentSign;
					o.ase_texcoord4.xyz = ase_worldBitangent;
					
					o.ase_texcoord1.xyz = v.ase_texcoord.xyz;
					
					//setting value to unused interpolator channels and avoid initialization warnings
					o.ase_texcoord1.w = 0;
					o.ase_texcoord2.w = 0;
					o.ase_texcoord3.w = 0;
					o.ase_texcoord4.w = 0;
					float3 vertexValue = float3(0, 0, 0);
					#if ASE_ABSOLUTE_VERTEX_POS
					vertexValue = v.vertex.xyz;
					#endif
					vertexValue = vertexValue;
					#if ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
					#else
					v.vertex.xyz += vertexValue;
					#endif
					o.vertex = UnityObjectToClipPos(v.vertex);

					#ifdef ASE_NEEDS_FRAG_WORLD_POSITION
					o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
					#endif
					return o;
				}

				fixed4 frag(v2f i ) : SV_Target
				{
					UNITY_SETUP_INSTANCE_ID(i);
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
					fixed4 finalColor;
					#ifdef ASE_NEEDS_FRAG_WORLD_POSITION
					float3 WorldPosition = i.worldPos;
					#endif
					float2 uv_Normal = i.ase_texcoord1.xyz.xy * _Normal_ST.xy + _Normal_ST.zw;
					float3 ase_worldTangent = i.ase_texcoord2.xyz;
					float3 ase_worldNormal = i.ase_texcoord3.xyz;
					float3 ase_worldBitangent = i.ase_texcoord4.xyz;
					float3 tanToWorld0 = float3( ase_worldTangent.x, ase_worldBitangent.x, ase_worldNormal.x );
					float3 tanToWorld1 = float3( ase_worldTangent.y, ase_worldBitangent.y, ase_worldNormal.y );
					float3 tanToWorld2 = float3( ase_worldTangent.z, ase_worldBitangent.z, ase_worldNormal.z );
					float3 ase_worldViewDir = UnityWorldSpaceViewDir(WorldPosition);
					ase_worldViewDir = normalize(ase_worldViewDir);
					float3 worldRefl13 = reflect( -ase_worldViewDir, float3( dot( tanToWorld0, tex2D( _Normal, uv_Normal ).rgb ), dot( tanToWorld1, tex2D( _Normal, uv_Normal ).rgb ), dot( tanToWorld2, tex2D( _Normal, uv_Normal ).rgb ) ) );
					float3 WorldReflection25 = worldRefl13;
					float4 ReflectionTex231 = texCUBE( _ReflectionTex2, WorldReflection25 );
					float fresnelNdotV16 = dot( ase_worldNormal, ase_worldViewDir );
					float fresnelNode16 = ( _FresnelMaskBias + _FresnelMaskScale * pow( 1.0 - fresnelNdotV16, _FresnelMaskPower ) );
					float4 FrontColor39 = ( ( ReflectionTex231 + ( ReflectionTex231 * _FrontStrength ) ) * fresnelNode16 );
					

					finalColor = FrontColor39;
					return finalColor;
				}
				ENDCG
			}
			
	}
	CustomEditor "ASEMaterialInspector"
	
	Fallback "Diffuse"
}
/*ASEBEGIN
Version=18912
0;0;2560;1371;3072.188;668.3284;1.476082;True;True
Node;AmplifyShaderEditor.CommentaryNode;26;-2444.865,-379.9081;Inherit;False;845.3763;280;WorldReflection;3;21;13;25;;1,1,1,1;0;0
Node;AmplifyShaderEditor.SamplerNode;21;-2394.865,-329.9081;Inherit;True;Property;_Normal;Normal;3;0;Create;True;0;0;0;False;0;False;-1;None;None;True;0;False;bump;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.WorldReflectionVector;13;-2050.509,-327.892;Inherit;False;False;1;0;FLOAT3;0,0,0;False;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.CommentaryNode;32;-2438.652,-41.22891;Inherit;False;896;301;ReflectionTex2;3;28;10;31;;1,1,1,1;0;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;25;-1834.822,-327.1566;Inherit;False;WorldReflection;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;28;-2388.652,29.77111;Inherit;True;25;WorldReflection;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SamplerNode;10;-2094.964,16.7405;Inherit;True;Property;_ReflectionTex2;ReflectionTex2;1;0;Create;True;0;0;0;False;0;False;-1;None;5cce05b87588f25419fa89c7ebe14d7e;True;0;False;white;LockedToCube;False;Object;-1;Auto;Cube;8;0;SAMPLERCUBE;;False;1;FLOAT3;0,0,0;False;2;FLOAT;0;False;3;FLOAT3;0,0,0;False;4;FLOAT3;0,0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.CommentaryNode;40;-1520.183,236.993;Inherit;False;1248.385;736.2305;FrontColor;10;18;19;20;16;24;22;23;38;17;39;;1,1,1,1;0;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;31;-1772.652,20.77111;Inherit;False;ReflectionTex2;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;23;-1181.292,494.7032;Inherit;False;Property;_FrontStrength;FrontStrength;5;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;38;-1233.892,301.8469;Inherit;False;31;ReflectionTex2;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;18;-1467.184,667.2241;Inherit;False;Property;_FresnelMaskBias;FresnelMaskBias;6;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;20;-1470.184,858.2238;Inherit;False;Property;_FresnelMaskPower;FresnelMaskPower;8;0;Create;True;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;24;-924.359,376.4767;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;19;-1470.184,761.2237;Inherit;False;Property;_FresnelMaskScale;FresnelMaskScale;7;0;Create;True;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;22;-745.7266,286.993;Inherit;False;2;2;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.FresnelNode;16;-1197.735,634.9422;Inherit;False;Standard;WorldNormal;ViewDir;False;False;5;0;FLOAT3;0,0,1;False;4;FLOAT3;0,0,0;False;1;FLOAT;0;False;2;FLOAT;1;False;3;FLOAT;2.77;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;17;-780.8431,530.4093;Inherit;True;2;2;0;COLOR;0,0,0,0;False;1;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.CommentaryNode;30;-2429.568,291.7435;Inherit;False;855.3334;297.8456;ReflectionTex01;3;27;4;29;;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;36;-1473.801,-390.0789;Inherit;False;790.0491;541.0588;BaseColor;6;35;12;34;14;33;15;;1,1,1,1;0;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;39;-499.7992,569.7454;Inherit;False;FrontColor;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;35;-911.7523,-236.3731;Inherit;False;baseColor;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;42;-354.2396,77.06526;Inherit;False;39;FrontColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;27;-2379.568,359.5891;Inherit;True;25;WorldReflection;1;0;OBJECT;;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SamplerNode;4;-2127.937,341.7436;Inherit;True;Property;_ReflectionTex;ReflectionTex;0;0;Create;True;0;0;0;False;0;False;-1;None;5cce05b87588f25419fa89c7ebe14d7e;True;0;False;white;LockedToCube;False;Object;-1;Auto;Cube;8;0;SAMPLERCUBE;;False;1;FLOAT3;0,0,0;False;2;FLOAT;0;False;3;FLOAT3;0,0,0;False;4;FLOAT3;0,0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RegisterLocalVarNode;29;-1809.568,349.5891;Inherit;False;ReflectionTex01;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;37;-353.8158,-69.53191;Inherit;False;35;baseColor;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.ColorNode;14;-1420.123,-141.8996;Float;False;Property;_Color;Color;2;0;Create;True;0;0;0;False;0;False;1,1,1,0;1,1,1,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.GetLocalVarNode;33;-1423.801,-340.0789;Inherit;False;29;ReflectionTex01;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;15;-1421.288,35.98017;Inherit;False;Property;_BackStrength;BackStrength;4;0;Create;True;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;12;-1063.147,-233.1284;Inherit;False;4;4;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;COLOR;0,0,0,0;False;3;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.GetLocalVarNode;34;-1420.801,-246.0791;Inherit;False;31;ReflectionTex2;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;0;-123.4602,-68.74239;Float;False;True;-1;2;ASEMaterialInspector;100;9;Learn/SimpleCrystal;9fc839302faa7d5489d7cbf60ad606fd;True;First Pass;0;0;First Pass;2;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;False;False;0;False;True;1;1;False;-1;0;False;-1;0;1;False;-1;0;False;-1;False;False;False;False;False;False;False;False;False;False;False;True;True;1;False;-1;False;False;False;False;False;False;False;False;False;False;False;True;1;False;-1;True;3;False;-1;False;True;1;LightMode=ForwardBase;False;False;0;Diffuse;0;0;Standard;1;Vertex Position,InvertActionOnDeselection;1;0;2;True;True;False;;False;0
Node;AmplifyShaderEditor.TemplateMultiPassMasterNode;1;-101.4758,74.43842;Float;False;False;-1;2;ASEMaterialInspector;100;9;New Amplify Shader;9fc839302faa7d5489d7cbf60ad606fd;True;Second Pass;0;1;Second Pass;2;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;2;RenderType=Opaque=RenderType;Queue=Geometry=Queue=0;False;False;0;True;True;4;1;False;-1;1;False;-1;0;1;False;-1;0;False;-1;False;False;False;False;False;False;False;False;False;False;False;True;True;0;False;-1;False;False;False;False;False;False;False;False;False;False;False;True;1;False;-1;True;3;False;-1;False;True;1;LightMode=ForwardBase;False;False;0;;0;0;Standard;0;False;0
WireConnection;13;0;21;0
WireConnection;25;0;13;0
WireConnection;10;1;28;0
WireConnection;31;0;10;0
WireConnection;24;0;38;0
WireConnection;24;1;23;0
WireConnection;22;0;38;0
WireConnection;22;1;24;0
WireConnection;16;1;18;0
WireConnection;16;2;19;0
WireConnection;16;3;20;0
WireConnection;17;0;22;0
WireConnection;17;1;16;0
WireConnection;39;0;17;0
WireConnection;35;0;12;0
WireConnection;4;1;27;0
WireConnection;29;0;4;0
WireConnection;12;0;33;0
WireConnection;12;1;34;0
WireConnection;12;2;14;0
WireConnection;12;3;15;0
WireConnection;0;0;37;0
WireConnection;1;0;42;0
ASEEND*/
//CHKSM=5D2CF17C138F6AB54C4FEFFC0C9F4FFD73877248