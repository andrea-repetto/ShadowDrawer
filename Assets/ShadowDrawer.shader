// Updated version with support to point and spot shadows
// Source: https://forum.unity.com/threads/matte-shadow.14438/page-2#post-4803875
Shader "Custom/ShadowDrawer"
{
    Properties
    {
        _Color ("Shadow Color", Color) = (0, 0, 0, 0.6)
        _ShadowBoost("sShadow Boost", float) = 1.0
    }

    CGINCLUDE

    #include "UnityCG.cginc"
    #include "AutoLight.cginc"

    struct v2f_shadow {
        float4 pos : SV_POSITION;
        float3 worldPos : TEXCOORD0;
        UNITY_LIGHTING_COORDS(1, 2)
    };

    half4 _Color;

    v2f_shadow vert_shadow(appdata_full v)
    {
        v2f_shadow o;
        o.pos = UnityObjectToClipPos(v.vertex);
        o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
        UNITY_TRANSFER_LIGHTING(o, v.texcoord1);
        return o;
    }

    half4 frag_shadow(v2f_shadow IN) : SV_Target
    {
        UNITY_LIGHT_ATTENUATION(atten, IN, IN.worldPos);
        return half4(_Color.rgb, lerp(_Color.a, 0, atten));
    }

    ENDCG

    SubShader
    {
        Tags { "Queue"="AlphaTest+49" }

        // Depth fill pass
        Pass
        {
            ColorMask 0

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            struct v2f {
                float4 pos : SV_POSITION;
            };

            v2f vert(appdata_full v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            half4 frag(v2f IN) : SV_Target
            {
                return (half4)0;
            }

            ENDCG
        }

        // Forward base pass
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert_shadow
            #pragma fragment frag_shadow
            #pragma multi_compile_fwdbase
            ENDCG
        }

        // Forward add pass
        Pass
        {
            Tags { "LightMode" = "ForwardAdd" }
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdadd_fullshadows
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
               
            float _ShadowBoost;
               
            struct v2f {
                float4 pos : SV_POSITION;
                float4 wpos : TEXCOORD2;
                LIGHTING_COORDS(0,1)
            };
            v2f vert (appdata_full v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.wpos = mul(unity_ObjectToWorld, v.vertex);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }
               
            float4 frag (v2f i) : COLOR
            {      
                fixed shadow = UNITY_SHADOW_ATTENUATION(1, i.wpos);
                float atten = 1;
                #if defined (POINT)
                    unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(i.wpos.xyz, 1)).xyz;
                    atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).r.UNITY_ATTEN_CHANNEL;
                #elif defined (SPOT)
                    float4 lightCoord = mul(unity_WorldToLight, float4(i.wpos.xyz, 1));
                    atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
                #endif
                atten*=_ShadowBoost;   
                return float4(_Color.xyz, _Color.a*(1-shadow)*atten);
            }
               
            ENDCG
        }
    }
    FallBack "Mobile/VertexLit"
}
