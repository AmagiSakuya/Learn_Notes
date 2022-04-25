// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Learn/Nebula"
{
	Properties
	{
		_NebulaTex("NebulaTex", 2D) = "white" {}
		_NebulaSpeed("NebulaSpeed", Vector) = (0,0,0,0)
		_NebulaColor("NebulaColor", Color) = (1,0.6035817,0.1132075,1)
		_NebulaStrength("NebulaStrength", Float) = 1
		_NebulaXSmooth("NebulaXSmooth", Range( 0 , 0.5)) = 0
		_NebulaYSmooth("NebulaYSmooth", Range( 0 , 0.5)) = 0
		_NebulaNosie("NebulaNosie", 2D) = "white" {}
		_NoiseStrength("NoiseStrength", Range( 0 , 0.4)) = 0
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] __dirty( "", Int ) = 1
	}

	SubShader
	{
		Tags{ "RenderType" = "Custom"  "Queue" = "Transparent+0" "IgnoreProjector" = "True" "IsEmissive" = "true"  }
		Cull Off
		ZWrite Off
		Blend SrcAlpha One
		
		CGINCLUDE
		#include "UnityShaderVariables.cginc"
		#include "UnityPBSLighting.cginc"
		#include "Lighting.cginc"
		#pragma target 3.0
		struct Input
		{
			float2 uv_texcoord;
		};

		uniform float4 _NebulaColor;
		uniform sampler2D _NebulaTex;
		uniform float2 _NebulaSpeed;
		uniform float4 _NebulaTex_ST;
		uniform sampler2D _NebulaNosie;
		uniform float4 _NebulaNosie_ST;
		uniform float _NoiseStrength;
		uniform float _NebulaStrength;
		uniform float _NebulaXSmooth;
		uniform float _NebulaYSmooth;

		inline half4 LightingUnlit( SurfaceOutput s, half3 lightDir, half atten )
		{
			return half4 ( 0, 0, 0, s.Alpha );
		}

		void surf( Input i , inout SurfaceOutput o )
		{
			float2 uv_NebulaTex = i.uv_texcoord * _NebulaTex_ST.xy + _NebulaTex_ST.zw;
			float2 panner6 = ( 1.0 * _Time.y * _NebulaSpeed + uv_NebulaTex);
			float2 uv_NebulaNosie = i.uv_texcoord * _NebulaNosie_ST.xy + _NebulaNosie_ST.zw;
			float4 m_NebulaTex41 = tex2D( _NebulaTex, ( panner6 + ( (tex2D( _NebulaNosie, uv_NebulaNosie )).rg * _NoiseStrength ) ) );
			float m_NebulaStrength38 = _NebulaStrength;
			o.Emission = ( _NebulaColor * m_NebulaTex41 * m_NebulaStrength38 ).rgb;
			float smoothstepResult30 = smoothstep( _NebulaXSmooth , 1.0 , ( 1.0 - abs( (i.uv_texcoord.x*1.0 + -0.5) ) ));
			float smoothstepResult25 = smoothstep( _NebulaYSmooth , 1.0 , ( 1.0 - i.uv_texcoord.y ));
			float OpactiySmooth36 = ( smoothstepResult30 * smoothstepResult25 );
			o.Alpha = ( (m_NebulaTex41).r * m_NebulaStrength38 * OpactiySmooth36 );
		}

		ENDCG
		CGPROGRAM
		#pragma surface surf Unlit keepalpha fullforwardshadows 

		ENDCG
		Pass
		{
			Name "ShadowCaster"
			Tags{ "LightMode" = "ShadowCaster" }
			ZWrite On
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
			#pragma multi_compile_shadowcaster
			#pragma multi_compile UNITY_PASS_SHADOWCASTER
			#pragma skip_variants FOG_LINEAR FOG_EXP FOG_EXP2
			#include "HLSLSupport.cginc"
			#if ( SHADER_API_D3D11 || SHADER_API_GLCORE || SHADER_API_GLES || SHADER_API_GLES3 || SHADER_API_METAL || SHADER_API_VULKAN )
				#define CAN_SKIP_VPOS
			#endif
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "UnityPBSLighting.cginc"
			sampler3D _DitherMaskLOD;
			struct v2f
			{
				V2F_SHADOW_CASTER;
				float2 customPack1 : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};
			v2f vert( appdata_full v )
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID( v );
				UNITY_INITIALIZE_OUTPUT( v2f, o );
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO( o );
				UNITY_TRANSFER_INSTANCE_ID( v, o );
				Input customInputData;
				float3 worldPos = mul( unity_ObjectToWorld, v.vertex ).xyz;
				half3 worldNormal = UnityObjectToWorldNormal( v.normal );
				o.customPack1.xy = customInputData.uv_texcoord;
				o.customPack1.xy = v.texcoord;
				o.worldPos = worldPos;
				TRANSFER_SHADOW_CASTER_NORMALOFFSET( o )
				return o;
			}
			half4 frag( v2f IN
			#if !defined( CAN_SKIP_VPOS )
			, UNITY_VPOS_TYPE vpos : VPOS
			#endif
			) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID( IN );
				Input surfIN;
				UNITY_INITIALIZE_OUTPUT( Input, surfIN );
				surfIN.uv_texcoord = IN.customPack1.xy;
				float3 worldPos = IN.worldPos;
				half3 worldViewDir = normalize( UnityWorldSpaceViewDir( worldPos ) );
				SurfaceOutput o;
				UNITY_INITIALIZE_OUTPUT( SurfaceOutput, o )
				surf( surfIN, o );
				#if defined( CAN_SKIP_VPOS )
				float2 vpos = IN.pos;
				#endif
				half alphaRef = tex3D( _DitherMaskLOD, float3( vpos.xy * 0.25, o.Alpha * 0.9375 ) ).a;
				clip( alphaRef - 0.01 );
				SHADOW_CASTER_FRAGMENT( IN )
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
	CustomEditor "ASEMaterialInspector"
}
/*ASEBEGIN
Version=18912
576;524.6667;1908;1141;2188.197;-645.8041;1;True;True
Node;AmplifyShaderEditor.CommentaryNode;35;-1928.276,1457.84;Inherit;False;1935.226;655.5146;OpactiySmooth;11;34;29;27;19;32;33;20;28;25;30;36;;1,1,1,1;0;0
Node;AmplifyShaderEditor.CommentaryNode;47;-1932.108,727.0894;Inherit;False;1543.782;689.0538;m_NebulaTex;10;41;4;6;5;8;48;49;50;51;52;;1,1,1,1;0;0
Node;AmplifyShaderEditor.TexCoordVertexDataNode;19;-1878.276,1527.586;Inherit;False;0;2;0;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SamplerNode;48;-1868.9,1078.415;Inherit;True;Property;_NebulaNosie;NebulaNosie;7;0;Create;True;0;0;0;False;0;False;-1;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.ScaleAndOffsetNode;27;-1637.652,1519.571;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;1;False;2;FLOAT;-0.5;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;52;-1526.197,1159.804;Inherit;False;Property;_NoiseStrength;NoiseStrength;8;0;Create;True;0;0;0;False;0;False;0;0;0;0.4;0;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;5;-1881.713,796.7233;Inherit;False;0;4;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SwizzleNode;50;-1518.364,958.3133;Inherit;False;FLOAT2;0;1;2;3;1;0;COLOR;0,0,0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.Vector2Node;8;-1882.108,926.1431;Inherit;False;Property;_NebulaSpeed;NebulaSpeed;2;0;Create;True;0;0;0;False;0;False;0,0;0,0;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.AbsOpNode;28;-1440.742,1518.568;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;51;-1340.197,1036.804;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT;0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.PannerNode;6;-1624.968,804.7241;Inherit;False;3;0;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.OneMinusNode;20;-1305.097,1692.731;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.OneMinusNode;29;-1311.938,1515.879;Inherit;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;49;-1291.364,811.3133;Inherit;False;2;2;0;FLOAT2;0,0;False;1;FLOAT2;0,0;False;1;FLOAT2;0
Node;AmplifyShaderEditor.RangedFloatNode;32;-1160.813,1609.719;Inherit;False;Property;_NebulaXSmooth;NebulaXSmooth;5;0;Create;True;0;0;0;False;0;False;0;0;0;0.5;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;33;-1153.711,1813.606;Inherit;False;Property;_NebulaYSmooth;NebulaYSmooth;6;0;Create;True;0;0;0;False;0;False;0;0;0;0.5;0;1;FLOAT;0
Node;AmplifyShaderEditor.SmoothstepOpNode;25;-858.8349,1756.813;Inherit;True;3;0;FLOAT;0;False;1;FLOAT;0.04;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;4;-1103.813,785.5792;Inherit;True;Property;_NebulaTex;NebulaTex;1;0;Create;True;0;0;0;False;0;False;-1;ec7345125d2fcdc45ac4f5363319bb2d;ec7345125d2fcdc45ac4f5363319bb2d;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SmoothstepOpNode;30;-865.8312,1509.632;Inherit;True;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;34;-597.8414,1507.839;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;41;-790.5787,785.0574;Inherit;False;m_NebulaTex;-1;True;1;0;COLOR;0,0,0,0;False;1;COLOR;0
Node;AmplifyShaderEditor.RangedFloatNode;16;-1883.488,425.6486;Inherit;False;Property;_NebulaStrength;NebulaStrength;4;0;Create;True;0;0;0;False;0;False;1;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;38;-1645.964,429.8506;Inherit;False;m_NebulaStrength;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;43;-735.8052,289.0606;Inherit;False;41;m_NebulaTex;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;36;-345.2024,1503.014;Inherit;False;OpactiySmooth;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;14;-700.2823,-136.3309;Inherit;False;Property;_NebulaColor;NebulaColor;3;0;Create;True;0;0;0;False;0;False;1,0.6035817,0.1132075,1;0,0,0,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.GetLocalVarNode;39;-684.4252,119.8373;Inherit;False;38;m_NebulaStrength;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;42;-683.6926,36.89948;Inherit;False;41;m_NebulaTex;1;0;OBJECT;;False;1;COLOR;0
Node;AmplifyShaderEditor.SwizzleNode;46;-504.17,286.566;Inherit;False;FLOAT;0;1;2;3;1;0;COLOR;0,0,0,0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;40;-615.4296,391.1571;Inherit;False;38;m_NebulaStrength;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;37;-614.9184,485.6099;Inherit;False;36;OpactiySmooth;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;21;-300.1299,285.9627;Inherit;True;3;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;15;-359.1527,4.455083;Inherit;False;3;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;2;0,0;Float;False;True;-1;2;ASEMaterialInspector;0;0;Unlit;Learn/Nebula;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;False;False;False;False;False;False;Off;2;False;-1;0;False;-1;False;0;False;-1;0;False;-1;False;0;Custom;0.5;True;True;0;True;Custom;;Transparent;All;18;all;True;True;True;True;0;False;-1;False;0;False;-1;255;False;-1;255;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;False;2;15;10;25;False;0.5;True;8;5;False;-1;1;False;-1;0;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;Relative;0;;0;-1;-1;-1;0;False;0;0;False;-1;-1;0;True;-1;0;0;0;False;0.1;False;-1;0;False;-1;False;15;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
WireConnection;27;0;19;1
WireConnection;50;0;48;0
WireConnection;28;0;27;0
WireConnection;51;0;50;0
WireConnection;51;1;52;0
WireConnection;6;0;5;0
WireConnection;6;2;8;0
WireConnection;20;0;19;2
WireConnection;29;0;28;0
WireConnection;49;0;6;0
WireConnection;49;1;51;0
WireConnection;25;0;20;0
WireConnection;25;1;33;0
WireConnection;4;1;49;0
WireConnection;30;0;29;0
WireConnection;30;1;32;0
WireConnection;34;0;30;0
WireConnection;34;1;25;0
WireConnection;41;0;4;0
WireConnection;38;0;16;0
WireConnection;36;0;34;0
WireConnection;46;0;43;0
WireConnection;21;0;46;0
WireConnection;21;1;40;0
WireConnection;21;2;37;0
WireConnection;15;0;14;0
WireConnection;15;1;42;0
WireConnection;15;2;39;0
WireConnection;2;2;15;0
WireConnection;2;9;21;0
ASEEND*/
//CHKSM=4F3CF094AD88E4C1290A344190C574293419BDAA