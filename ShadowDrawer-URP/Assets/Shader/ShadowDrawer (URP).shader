Shader "Custom/ShadowDrawer (URP)"
{
	Properties
	{
		_Color("Shadow Color", color) = (1, 1, 1, 1)
		[ToggleOff] _Receive_Shadows("Receive Shadows", Float) = 1.0
	}

	SubShader
	{
		Tags { "RenderType" = "Opaque" "Queue" = "AlphaTest+49" "RenderPipeline" = "UniversalRenderPipeline" }
		
		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
		ENDHLSL

		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma shader_feature _RECEIVE_SHADOWS_OFF

			struct a2v
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 worldPos : TEXCOORD0;
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
				float4 shadowCoord : TEXCOORD1;
				#endif
			};

			CBUFFER_START(UnityPerMaterial)
			real4 _Color;
			CBUFFER_END

			v2f vert(a2v i)
			{
				v2f o;
				o.worldPos = TransformObjectToWorld(i.vertex.xyz);
				o.vertex = TransformWorldToHClip(o.worldPos.xyz);
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
				o.shadowCoord = TransformWorldToShadowCoord(o.worldPos);
				#endif
				return o;
			}

			real4 frag(v2f i) : SV_TARGET
			{
				real4 o = _Color;
				// 获取主光源阴影坐标
				#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
					float4 shadowCoord = i.shadowCoord;
				#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
					float4 shadowCoord = TransformWorldToShadowCoord(i.worldPos);
				#else
					float4 shadowCoord = float4(0, 0, 0, 0);
				#endif

				Light main = GetMainLight(shadowCoord); // 获得主光源结构体（内部包含阴影衰减）

				o *= (float4(1,1,1,1) - main.shadowAttenuation);
				#ifdef _ADDITIONAL_LIGHTS
				uint pixelLightCount = GetAdditionalLightsCount();
				for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
					{
						Light light = GetAdditionalLight(lightIndex, i.worldPos); // 获得额外光源结构体（内部包含阴影衰减）
						o *= light.shadowAttenuation;
					}
				#endif
				return o;
			}
			ENDHLSL
		}

		Pass
		{

			Name "ShadowCaster"
			Tags{"LightMode" = "ShadowCaster"}
			ZWrite On
			ZTest LEqual
			ColorMask 0
			Cull[_Cull]

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			struct a2v
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;

			};

			float3 _LightDirection; // 将会由Unity 完成赋值

			float4 GetShadowPositionHClip(float3 positionWS, float3 normalWS)
			{
				float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

				#if UNITY_REVERSED_Z
					positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#else
					positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
				#endif
				return positionCS;
			}

			v2f vert(a2v i)
			{
				v2f o;
				float3 worldPos = TransformObjectToWorld(i.vertex.xyz);
				float3 normal = TransformObjectToWorldNormal(i.normal);
				o.vertex = GetShadowPositionHClip(worldPos, normal);
				return o;

			}

			half4 frag(v2f i) : SV_TARGET
			{
				return 0;
			}

			ENDHLSL
		}
	}
}