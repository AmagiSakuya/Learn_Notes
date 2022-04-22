// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "Learn/SimpleFire"
{
	Properties
	{
		[HDR]_NoiseMap("_NoiseMap", 2D) = "white" {}
		_UVSpeed("UVSpeed", Vector) = (0,-1,0,0)
		[HDR]_FireColor("FireColor", Color) = (0.8773585,0,0,1)
		_Smooth("Smooth", Float) = 0
		_FireRamp("FireRamp", 2D) = "black" {}
		_FireMask("FireMask", 2D) = "white" {}
		_fireShapeNoise("fireShapeNoise", Float) = 0.02
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] __dirty( "", Int ) = 1
	}

	SubShader
	{
		Tags{ "RenderType" = "Transparent"  "Queue" = "Transparent+0" "IgnoreProjector" = "True" "IsEmissive" = "true"  }
		Cull Off
		CGPROGRAM
		#include "UnityShaderVariables.cginc"
		#pragma target 3.0
		#pragma surface surf Unlit alpha:fade keepalpha noshadow 
		struct Input
		{
			float2 uv_texcoord;
		};

		uniform float4 _FireColor;
		uniform sampler2D _FireMask;
		uniform float4 _FireMask_ST;
		uniform sampler2D _NoiseMap;
		uniform float2 _UVSpeed;
		uniform float4 _NoiseMap_ST;
		uniform float _fireShapeNoise;
		uniform float _Smooth;
		uniform sampler2D _FireRamp;
		uniform float4 _FireRamp_ST;

		inline half4 LightingUnlit( SurfaceOutput s, half3 lightDir, half atten )
		{
			return half4 ( 0, 0, 0, s.Alpha );
		}

		void surf( Input i , inout SurfaceOutput o )
		{
			o.Emission = _FireColor.rgb;
			float2 uv_FireMask = i.uv_texcoord * _FireMask_ST.xy + _FireMask_ST.zw;
			float2 uv_NoiseMap = i.uv_texcoord * _NoiseMap_ST.xy + _NoiseMap_ST.zw;
			float2 panner59 = ( 1.0 * _Time.y * _UVSpeed + uv_NoiseMap);
			float NoiseMap83 = tex2D( _NoiseMap, panner59 ).r;
			float4 appendResult100 = (float4(( uv_FireMask.x + ( (NoiseMap83*2.0 + -1.0) * _fireShapeNoise ) ) , uv_FireMask.y , 0.0 , 0.0));
			float2 uv_FireRamp = i.uv_texcoord * _FireRamp_ST.xy + _FireRamp_ST.zw;
			float smoothstepResult65 = smoothstep( NoiseMap83 , ( NoiseMap83 - _Smooth ) , tex2D( _FireRamp, uv_FireRamp ).r);
			float NoiseUV71 = smoothstepResult65;
			float Opacity95 = ( tex2D( _FireMask, appendResult100.xy ).r * NoiseUV71 );
			o.Alpha = Opacity95;
		}

		ENDCG
	}
	CustomEditor "ASEMaterialInspector"
}
/*ASEBEGIN
Version=18912
10;663.3334;1540;805;3482.121;684.5211;3.024466;True;True
Node;AmplifyShaderEditor.CommentaryNode;73;-2209.944,-111.4059;Inherit;False;1452.796;629.9996;噪点动画;10;58;63;59;10;67;66;69;65;71;83;;1,1,1,1;0;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;58;-2185.583,8.12581;Inherit;False;0;10;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.Vector2Node;63;-2176.752,165.3897;Inherit;False;Property;_UVSpeed;UVSpeed;1;0;Create;True;0;0;0;False;0;False;0,-1;0,-1;0;3;FLOAT2;0;FLOAT;1;FLOAT;2
Node;AmplifyShaderEditor.PannerNode;59;-1909.808,46.33184;Inherit;False;3;0;FLOAT2;0,0;False;2;FLOAT2;0,0;False;1;FLOAT;1;False;1;FLOAT2;0
Node;AmplifyShaderEditor.SamplerNode;10;-1709.511,166.0981;Inherit;True;Property;_NoiseMap;_NoiseMap;0;1;[HDR];Create;True;0;0;0;False;0;False;-1;a910559a856589b4cb637f2c21d78172;a910559a856589b4cb637f2c21d78172;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.CommentaryNode;101;-2220.901,569.5136;Inherit;False;1802.204;577.9341;透明度;11;91;93;99;92;89;90;100;94;74;87;95;;1,1,1,1;0;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;83;-1421.163,188.0037;Inherit;False;NoiseMap;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.GetLocalVarNode;91;-2170.901,791.609;Inherit;True;83;NoiseMap;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;67;-1393.251,319.1434;Inherit;False;Property;_Smooth;Smooth;3;0;Create;True;0;0;0;False;0;False;0;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.ScaleAndOffsetNode;99;-1935.793,796.502;Inherit;True;3;0;FLOAT;0;False;1;FLOAT;2;False;2;FLOAT;-1;False;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;93;-1916.576,1032.448;Inherit;False;Property;_fireShapeNoise;fireShapeNoise;6;0;Create;True;0;0;0;False;0;False;0.02;0.02;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;69;-1713.702,-60.11382;Inherit;True;Property;_FireRamp;FireRamp;4;0;Create;True;0;0;0;False;0;False;-1;2c1caefa5ce347d49a9567e23a9b7158;None;True;0;False;black;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleSubtractOpNode;66;-1194.853,190.8599;Inherit;False;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.TextureCoordinatesNode;89;-1845.053,619.5136;Inherit;False;0;74;2;3;2;SAMPLER2D;;False;0;FLOAT2;1,1;False;1;FLOAT2;0,0;False;5;FLOAT2;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;92;-1677.058,800.483;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SmoothstepOpNode;65;-1163.09,-7.150982;Inherit;False;3;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;1;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;90;-1569.063,632.241;Inherit;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;71;-972.0961,30.68023;Inherit;False;NoiseUV;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;100;-1372.743,628.3181;Inherit;False;FLOAT4;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT4;0
Node;AmplifyShaderEditor.SamplerNode;74;-1191.455,620.5927;Inherit;True;Property;_FireMask;FireMask;5;0;Create;True;0;0;0;False;0;False;-1;249a0301958293241a15dda7e7e49028;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;8;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;6;FLOAT;0;False;7;SAMPLERSTATE;;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.GetLocalVarNode;94;-1180.275,832.8599;Inherit;True;71;NoiseUV;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;87;-863.8543,620.3722;Inherit;True;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;95;-646.6954,627.3339;Inherit;False;Opacity;-1;True;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;64;-462.1062,-80.50571;Inherit;False;Property;_FireColor;FireColor;2;1;[HDR];Create;True;0;0;0;False;0;False;0.8773585,0,0,1;0,0,0,0;True;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.GetLocalVarNode;97;-450.8707,153.7081;Inherit;False;95;Opacity;1;0;OBJECT;;False;1;FLOAT;0
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;42;-134.8902,-65.5535;Float;False;True;-1;2;ASEMaterialInspector;0;0;Unlit;Learn/Fire01;False;False;False;False;False;False;False;False;False;False;False;False;False;False;True;False;False;False;False;False;False;Off;0;False;-1;0;False;-1;False;0;False;-1;0;False;-1;False;0;Transparent;0.5;True;False;0;False;Transparent;;Transparent;All;18;all;True;True;True;True;0;False;-1;False;0;False;-1;255;False;-1;255;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;False;2;15;10;25;False;0.5;False;2;5;False;-1;10;False;-1;0;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;Relative;0;;-1;-1;-1;-1;0;False;0;0;False;-1;-1;0;True;46;0;0;0;False;0.1;False;-1;0;False;-1;False;15;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
WireConnection;59;0;58;0
WireConnection;59;2;63;0
WireConnection;10;1;59;0
WireConnection;83;0;10;1
WireConnection;99;0;91;0
WireConnection;66;0;83;0
WireConnection;66;1;67;0
WireConnection;92;0;99;0
WireConnection;92;1;93;0
WireConnection;65;0;69;1
WireConnection;65;1;83;0
WireConnection;65;2;66;0
WireConnection;90;0;89;1
WireConnection;90;1;92;0
WireConnection;71;0;65;0
WireConnection;100;0;90;0
WireConnection;100;1;89;2
WireConnection;74;1;100;0
WireConnection;87;0;74;1
WireConnection;87;1;94;0
WireConnection;95;0;87;0
WireConnection;42;2;64;0
WireConnection;42;9;97;0
ASEEND*/
//CHKSM=F58B8B5A5ACE58DCC4DCD5C59DA89AB4322D6E9C