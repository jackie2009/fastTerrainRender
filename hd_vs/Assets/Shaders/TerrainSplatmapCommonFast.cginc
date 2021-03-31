// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
#pragma exclude_renderers d3d11 gles

#ifndef TERRAIN_SPLATMAP_COMMON_CGINC_INCLUDED
#define TERRAIN_SPLATMAP_COMMON_CGINC_INCLUDED

struct Input
{
    float2 uv_Splat0 : TEXCOORD0;
    float2 uv_Splat1 : TEXCOORD1;
    float2 uv_Splat2 : TEXCOORD2;
    float2 uv_Splat3 : TEXCOORD3;
    float2 tc_Control : TEXCOORD4;  // Not prefixing '_Contorl' with 'uv' allows a tighter packing of interpolators, which is necessary to support directional lightmap.
    UNITY_FOG_COORDS(5)
};

sampler2D _Control;
float4 _Control_ST;
sampler2D _Splat0,_Splat1,_Splat2,_Splat3;
uniform sampler2D SpaltIDTex;
   
UNITY_DECLARE_TEX2DARRAY(AlbedoAtlas);
UNITY_DECLARE_TEX2DARRAY(NormalAtlas);
UNITY_DECLARE_TEX2DARRAY(SpaltWeightTex);


#ifdef _TERRAIN_NORMAL_MAP
    sampler2D _Normal0, _Normal1, _Normal2, _Normal3;
#endif

void SplatmapVert(inout appdata_full v, out Input data)
{
    UNITY_INITIALIZE_OUTPUT(Input, data);
    data.tc_Control = TRANSFORM_TEX(v.texcoord, _Control);  // Need to manually transform uv here, as we choose not to use 'uv' prefix for this texcoord.
    float4 pos = UnityObjectToClipPos(v.vertex);
    UNITY_TRANSFER_FOG(data, pos);


    v.tangent.xyz = cross(v.normal, float3(0,0,1));
    v.tangent.w = -1;

}
 

#ifdef TERRAIN_STANDARD_SHADER
 void SplatmapMix(Input IN, half4 defaultAlpha, out half4 splat_control, out half weight, out fixed4 mixedDiffuse, inout fixed3 mixedNormal)
#else
 void SplatmapMix(Input IN, out float4 splat_control, out half weight, out fixed4 mixedDiffuse, inout fixed3 mixedNormal)
#endif
 {
     half2 offsetFix = -half2(0.5, 0.5) / 1024.0;
     splat_control = tex2D(SpaltIDTex, IN.tc_Control+ offsetFix);
     float4  splat_control_1_0 = tex2D(SpaltIDTex, IN.tc_Control+ offsetFix +half2(1,0)/1024.0);
     float4  splat_control_0_1 = tex2D(SpaltIDTex, IN.tc_Control+ offsetFix +half2(0,1)/1024.0);
     float4  splat_control_1_1 = tex2D(SpaltIDTex, IN.tc_Control+ offsetFix +half2(1,1)/1024.0);

     //极大提高gpu渲染性能 因为做了如果周围是同图层就不做任何混合与插值计算
     bool needMix = splat_control.b+ splat_control_1_0.b+ splat_control_0_1.b+ splat_control_1_1.b > 0.001;

     weight = 1;

#if !defined(SHADER_API_MOBILE) && defined(TERRAIN_SPLAT_ADDPASS)
     clip(weight == 0.0f ? -1 : 1);
#endif
     float clipSize = 1024;//单张图片大小  
 
     float2 initScale = (IN.tc_Control * 500 / 33);//terrain Size/ tile scale
     int id = (int)(splat_control.r * 16 + 0.5);

        

     //计算第一重要 相邻4个点颜色
     float3 uvR = float3(initScale, id);//
     half3 colorR = UNITY_SAMPLE_TEX2DARRAY(AlbedoAtlas, uvR)* (1-splat_control.b);
     if (needMix) {
         int id_0_1 = (int)(splat_control_0_1.r * 16 + 0.5);
         float3 uvR_0_1 = float3(initScale, id_0_1);//
         half3 colorR_0_1 = UNITY_SAMPLE_TEX2DARRAY(AlbedoAtlas, uvR_0_1) * (1 - splat_control_0_1.b);

         int id_1_0 = (int)(splat_control_1_0.r * 16 + 0.5);
         float3 uvR_1_0 = float3(initScale, id_1_0);//
         half3 colorR_1_0 = UNITY_SAMPLE_TEX2DARRAY(AlbedoAtlas, uvR_1_0) * (1 - splat_control_1_0.b);

         int id_1_1 = (int)(splat_control_1_1.r * 16 + 0.5);
         float3 uvR_1_1 = float3(initScale, id_1_1);//
         half3 colorR_1_1 = UNITY_SAMPLE_TEX2DARRAY(AlbedoAtlas, uvR_1_1) * (1 - splat_control_1_1.b);
         //计算双线性插值
         half2 uv_frac = frac((IN.tc_Control + offsetFix) * 1024);
         half3 mixedColorR = lerp(lerp(colorR, colorR_1_0, uv_frac.x), lerp(colorR_0_1, colorR_1_1, uv_frac.x), uv_frac.y);

         //计算第二重要 相邻4个点颜色
         id = (int)(splat_control.g * 16 + 0.5);
         float3 uvG = float3(initScale, id);//
         half3 colorG = UNITY_SAMPLE_TEX2DARRAY(AlbedoAtlas, uvG) * splat_control.b;

         id_0_1 = (int)(splat_control_0_1.g * 16 + 0.5);
         float3 uvG_0_1 = float3(initScale, id_0_1);//
         half3 colorG_0_1 = UNITY_SAMPLE_TEX2DARRAY(AlbedoAtlas, uvG_0_1) * splat_control_0_1.b;

         id_1_0 = (int)(splat_control_1_0.g * 16 + 0.5);
         float3 uvG_1_0 = float3(initScale, id_1_0);//
         half3 colorG_1_0 = UNITY_SAMPLE_TEX2DARRAY(AlbedoAtlas, uvG_1_0) * splat_control_1_0.b;

         id_1_1 = (int)(splat_control_1_1.g * 16 + 0.5);
         float3 uvG_1_1 = float3(initScale, id_1_1);//
         half3 colorG_1_1 = UNITY_SAMPLE_TEX2DARRAY(AlbedoAtlas, uvG_1_1) * splat_control_1_1.b;
         //计算双线性插值
         half3 mixedColorG = lerp(lerp(colorG, colorG_1_0, uv_frac.x), lerp(colorG_0_1, colorG_1_1, uv_frac.x), uv_frac.y);

         half weightG = 0;

         mixedDiffuse.rgb = mixedColorR + mixedColorG;// *(1 - weightG - weightB) + colorG * weightG + colorB * weightB;
         mixedDiffuse.a = 0;//smoothness


         //法线只采样占比最高的那张


         fixed4  nrm = UNITY_SAMPLE_TEX2DARRAY(NormalAtlas, uvR);
         fixed4  nrm_0_1 = UNITY_SAMPLE_TEX2DARRAY(NormalAtlas, uvR_0_1);
         fixed4  nrm_1_0 = UNITY_SAMPLE_TEX2DARRAY(NormalAtlas, uvR_1_0);
         fixed4  nrm_1_1 = UNITY_SAMPLE_TEX2DARRAY(NormalAtlas, uvR_1_1);

         nrm = lerp(lerp(nrm, nrm_1_0, uv_frac.x), lerp(nrm_0_1, nrm_1_1, uv_frac.x), uv_frac.y);

         mixedNormal = UnpackNormal(nrm);
     }
     else {
         mixedDiffuse.rgb = colorR;// *(1 - weightG - weightB) + colorG * weightG + colorB * weightB;
         mixedDiffuse.a = 0;//smoothness
         mixedNormal = UnpackNormal(UNITY_SAMPLE_TEX2DARRAY(NormalAtlas, uvR));
     }


 }
 

#ifndef TERRAIN_SURFACE_OUTPUT
    #define TERRAIN_SURFACE_OUTPUT SurfaceOutput
#endif

void SplatmapFinalColor(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 color)
{
    color *= o.Alpha;
    #ifdef TERRAIN_SPLAT_ADDPASS
        UNITY_APPLY_FOG_COLOR(IN.fogCoord, color, fixed4(0,0,0,0));
    #else
        UNITY_APPLY_FOG(IN.fogCoord, color);
    #endif
}

void SplatmapFinalPrepass(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 normalSpec)
{
    normalSpec *= o.Alpha;
}

void SplatmapFinalGBuffer(Input IN, TERRAIN_SURFACE_OUTPUT o, inout half4 outGBuffer0, inout half4 outGBuffer1, inout half4 outGBuffer2, inout half4 emission)
{
    UnityStandardDataApplyWeightToGbuffer(outGBuffer0, outGBuffer1, outGBuffer2, o.Alpha);
    emission *= o.Alpha;
}

#endif // TERRAIN_SPLATMAP_COMMON_CGINC_INCLUDED
