using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
 
using UnityEngine;

public class FastTerrain : MonoBehaviour
{
     public Texture2DArray albedoAtlas;
    public Texture2DArray normalAtlas;

    //splat r存放占比最大的那个地表索引，g存放占比第二大的那个地表索引 b存放g的占比 ，1-b=r的占比（丢弃第3重要图层都算给第一重要图层）
    public Texture2D splatID;
     public Shader terrainShader;
    public TerrainData normalTerrainData;//{ get { return GetComponent<Terrain>().terrainData; } }
    public TerrainData empytTerrainData;
#if UNITY_EDITOR
    [ContextMenu("MakeAlbedoAtlas")]
    // Update is called once per frame
    void MakeAlbedoAtlas()
    {
      
         int sqrCount = 4;
        int wid = normalTerrainData.splatPrototypes[0].texture.width;
        int hei =normalTerrainData.splatPrototypes[0].texture.height;

        int widNormal = normalTerrainData.splatPrototypes[0].normalMap.width;
        int heiNormal = normalTerrainData.splatPrototypes[0].normalMap.height;
        albedoAtlas = new Texture2DArray(wid, hei, sqrCount* sqrCount, normalTerrainData.splatPrototypes[0].texture.format, true,false);
        normalAtlas = new Texture2DArray(widNormal, heiNormal, sqrCount* sqrCount, normalTerrainData.splatPrototypes[0].normalMap.format, true,true);
         
        for (int i = 0; i < sqrCount; i++)
        {
            for (int j = 0; j < sqrCount; j++)
            {
                int index = i * sqrCount + j;

                if (index >= normalTerrainData.splatPrototypes.Length) break;
                for (int k = 0; k < normalTerrainData.splatPrototypes[index].texture.mipmapCount; k++)
                {
                    Graphics.CopyTexture(normalTerrainData.splatPrototypes[index].texture, 0, k, albedoAtlas, index, k);
 
                }
                for (int k = 0; k < normalTerrainData.splatPrototypes[index].normalMap.mipmapCount; k++)
                {
                    Graphics.CopyTexture(normalTerrainData.splatPrototypes[index].normalMap, 0, k, normalAtlas, index, k);
 
                }
     
            }
        }
 
  
    }


    struct SplatData
    {
        public int id;
        public float weight;
     }


    [ContextMenu("MakeSplat")]
    // Update is called once per frame
    void MakeSplat()
    {
      

         
        int wid = normalTerrainData.alphamapTextures[0].width;
        int hei = normalTerrainData.alphamapTextures[0].height;
        List<Color[]> colors = new List<Color[]>();
        //t.terrainData.alphamapTextures[i].GetPixels();
        for (int i = 0; i < normalTerrainData.alphamapTextures.Length; i++)
        {
            colors.Add(normalTerrainData.alphamapTextures[i].GetPixels());
        }

        splatID = new Texture2D(wid, hei, TextureFormat.RGB24, false, true);

        splatID.filterMode = FilterMode.Point;

        var splatIDColors = splatID.GetPixels();

   
 
        for (int i = 0; i < hei; i++)
        {
            for (int j = 0; j < wid; j++)
            {
                List<SplatData> splatDatas = new List<SplatData>();
                int index = i * wid + j;
   // splatIDColors[index].r=1 / 16.0f;
                //struct 是值引用 所以 Add到list后  可以复用（修改他属性不会影响已经加入的数据）
                for (int k = 0; k < colors.Count; k++)
                {
                    SplatData sd;
                    sd.id = k * 4;
                    sd.weight = colors[k][index].r;
                     splatDatas.Add(sd);
                    sd.id++;
                    sd.weight = colors[k][index].g;
 
                    splatDatas.Add(sd);
                    sd.id++;
                    sd.weight = colors[k][index].b;
 
                    splatDatas.Add(sd);
                    sd.id++;
                    sd.weight = colors[k][index].a;
 
                    splatDatas.Add(sd);
                }

            
                //按权重排序选出最重要几个
               splatDatas.Sort((x, y) => -(x.weight).CompareTo(y.weight));
       
 


                //只存最重要2个图层 用一点压缩方案可以一张图存更多图层 ,这里最多支持16张
                splatIDColors[index].r = splatDatas[0].id / 16f; //
                 splatIDColors[index].g = splatDatas[1].id / 16f;
                 splatIDColors[index].b = splatDatas[1].weight;
               
            }
        }


        splatID.SetPixels(splatIDColors);
        splatID.Apply();


 
    }


    

#endif
  
    [ContextMenu("UseFastMode")]
    void useFastMode()
    {
        Terrain t = GetComponent<Terrain>();
      t.terrainData = empytTerrainData;
       
        t.materialType = Terrain.MaterialType.Custom;
      
            t.materialTemplate = new Material(terrainShader);
     

        Shader.SetGlobalTexture("SpaltIDTex", splatID);
         Shader.SetGlobalTexture("AlbedoAtlas", albedoAtlas);
        Shader.SetGlobalTexture("NormalAtlas", normalAtlas);
        
    }

    [ContextMenu("UseBuildinMode")]
    void useBuildinMode()
    {
        Terrain t = GetComponent<Terrain>();
        t.terrainData = normalTerrainData;
        t.materialType = Terrain.MaterialType.BuiltInStandard;
        t.materialTemplate = null;
    }


    private bool fastMode = false;

    private void OnGUI()
    {
        if (GUILayout.Button(fastMode ? "自定义渲染ing" : "引擎默认渲染ing"))
        {
            fastMode = !fastMode;
            if (fastMode)
            {
                useFastMode();
            }
            else
            {
                useBuildinMode();
            }
        }
    }
}