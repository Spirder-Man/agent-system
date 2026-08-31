using System;
using System.Collections.Generic;
using System.Linq;
using Agent1.Models;
using Agent1.Services;

namespace Agent1.Tests.Stubs;

/// <summary>
/// IChemicalKnowledgeGraph 内存存根 — 用于 DeterministicRuleEngine / 静态门面
/// ChemicalSubstanceDatabase 等单元测试。
///
/// 真实 ChemicalKnowledgeGraph 强依赖 PostgreSQL（LoadFromDatabase），单测中不可用。
/// 种子数据为 db/migrations/002_chemical_knowledge_graph.sql 的完整内存副本：
///   35 种物质（含别名/危险类别/储存禁忌）+ 20 条安全距离 + 8 条法规版本
///   + 21 对精确禁忌配对（含类别级判定逻辑）
///
/// ⚠️ 同步纪律：本文件与 002_chemical_knowledge_graph.sql 双源同步，
/// 修改 SQL 种子时必须同步本文件（反之亦然），否则静态门面测试会与真实库漂移。
/// </summary>
public class StubChemicalKnowledgeGraph : IChemicalKnowledgeGraph
{
    private readonly List<ChemicalSubstance> _substances;
    private readonly List<SafetyDistanceRule> _safetyDistances;
    private readonly List<RegulationVersion> _regulations;
    private readonly List<StorageIncompatibilityRule> _incompatRules;

    // ── 物质种子（与 migration 002 逐行对应：name, en, cas, un, formula, state, fp, bp, threshold）──
    private static readonly (string Name, string En, string Cas, string Un, string Formula, string State, double? Fp, double? Bp, double Threshold)[] SubstanceSeed =
    {
        ("苯",       "Benzene",             "71-43-2",  "1114", "C6H6",    "液体",                  -11,   80.1,  50),
        ("甲苯",     "Toluene",             "108-88-3", "1294", "C7H8",    "液体",                  4,    110.6, 500),
        ("二甲苯",   "Xylene",              "1330-20-7","1307", "C8H10",   "液体",                  25,   138.5, 500),
        ("甲醇",     "Methanol",            "67-56-1",  "1230", "CH3OH",   "液体",                  11,    64.7, 500),
        ("乙醇",     "Ethanol",             "64-17-5",  "1170", "C2H5OH",  "液体",                  13,    78.3, 500),
        ("丙酮",     "Acetone",             "67-64-1",  "1090", "C3H6O",   "液体",                 -18,    56.1, 500),
        ("乙酸乙酯", "Ethyl acetate",       "141-78-6", "1173", "C4H8O2",  "液体",                  -4,    77.1, 500),
        ("环氧乙烷", "Ethylene oxide",      "75-21-8",  "1040", "C2H4O",   "气体（加压液化）",      -18,    10.7,  10),
        ("过氧化氢", "Hydrogen peroxide",   "7722-84-1","2015", "H2O2",    "液体",                 null,  150.2,  50),
        ("硝酸",     "Nitric acid",         "7697-37-2","2031", "HNO3",    "液体",                 null,    83,  100),
        ("硝酸铵",   "Ammonium nitrate",    "6484-52-2","1942", "NH4NO3",  "固体",                 null,   210,   50),
        ("高锰酸钾", "Potassium permanganate", "7722-64-7","1490", "KMnO4", "固体",                null,  null,   50),
        ("重铬酸钠", "Sodium dichromate",   "10588-01-9","3086", "Na2Cr2O7","固体",                null,   400,   50),
        ("氯",       "Chlorine",            "7782-50-5","1017", "Cl2",     "气体（加压液化）",      null,  -34.5,   5),
        ("氨",       "Ammonia",             "7664-41-7","1005", "NH3",     "气体（加压液化）",      null,  -33.4,  10),
        ("硫化氢",   "Hydrogen sulfide",    "7783-06-4","1053", "H2S",     "气体",                 null,  -60.3,   5),
        ("乙炔",     "Acetylene",           "74-86-2",  "1001", "C2H2",    "气体（溶解）",         -18,   -84,    1),
        ("氢气",     "Hydrogen",            "1333-74-0","1049", "H2",      "气体（压缩）",         null, -252.8,   5),
        ("硫酸",     "Sulfuric acid",       "7664-93-9","1830", "H2SO4",   "液体",                 null,   330,  100),
        ("盐酸",     "Hydrochloric acid",   "7647-01-0","1789", "HCl",     "液体（氯化氢水溶液）",  null, 108.6,    0),
        ("氢氧化钠", "Sodium hydroxide",    "1310-73-2","1823", "NaOH",    "固体",                 null,  1388,    0),
        ("氢氧化钾", "Potassium hydroxide", "1310-58-3","1813", "KOH",     "固体",                 null,  1320,    0),
        ("氢氟酸",   "Hydrofluoric acid",   "7664-39-3","1790", "HF",      "液体",                 null,   19.5,   1),
        ("乙酸",     "Acetic acid",         "64-19-7",  "2789", "CH3COOH", "液体",                  39,   118.1,   0),
        ("氰化钠",   "Sodium cyanide",      "143-33-9", "1689", "NaCN",    "固体",                 null,  1496,    1),
        ("甲醛",     "Formaldehyde",        "50-00-0",  "2209", "CH2O",    "液体（甲醛溶液）",      50,   -19.5,   5),
        ("苯乙烯",   "Styrene",             "100-42-5", "2055", "C8H8",    "液体",                  31,   145,   500),
        ("三氯甲烷", "Chloroform",          "67-66-3",  "1888", "CHCl3",   "液体",                 null,   61.2,   0),
        ("丙三醇",   "Glycerol",            "56-81-5",  "",     "C3H8O3",  "液体",                 160,   290,    0),
        ("氯化氢",   "Hydrogen chloride",   "7647-01-0","1050", "HCl",     "气体（液化）",         null,   -85,   20),
        ("二氧化硫", "Sulfur dioxide",      "7446-09-5","1079", "SO2",     "气体（液化）",         null,   -10,   20),
        ("氧气",     "Oxygen",              "7782-44-7","1072", "O2",      "气体（压缩/液化）",    null,  -183,   200),
        ("硫磺",     "Sulfur",              "7704-34-9","1350", "S8",      "固体",                 207,   444.6,  0),
        ("铝粉",     "Aluminium powder",    "7429-90-5","1396", "Al",      "固体（粉末）",         null,  2470,    0),
        ("氨溶液",   "Ammonia solution",    "1336-21-6","2672", "NH3·H2O", "液体",                 null,    38,   10),
    };

    // ── 别名种子 ──
    private static readonly Dictionary<string, string[]> AliasSeed = new()
    {
        ["苯"]       = new[] { "纯苯", "安息油" },
        ["甲苯"]     = new[] { "甲基苯", "Toluol" },
        ["二甲苯"]   = new[] { "混合二甲苯", "Xylol" },
        ["甲醇"]     = new[] { "木醇", "木精", "甲基醇" },
        ["乙醇"]     = new[] { "酒精", "火酒" },
        ["丙酮"]     = new[] { "二甲酮", "阿西通", "醋酮" },
        ["乙酸乙酯"] = new[] { "醋酸乙酯" },
        ["环氧乙烷"] = new[] { "氧化乙烯", "EO", "噁烷" },
        ["过氧化氢"] = new[] { "双氧水" },
        ["硝酸"]     = new[] { "硝镪水", "发烟硝酸" },
        ["硝酸铵"]   = new[] { "硝铵", "AN" },
        ["高锰酸钾"] = new[] { "灰锰氧", "PP粉" },
        ["重铬酸钠"] = new[] { "红矾钠" },
        ["氯"]       = new[] { "液氯", "氯气", "绿气" },
        ["氨"]       = new[] { "氨气", "液氨", "阿摩尼亚" },
        ["硫化氢"]   = new[] { "氢硫酸", "硫化氢气" },
        ["乙炔"]     = new[] { "电石气", "乙炔气" },
        ["氢气"]     = new[] { "氢" },
        ["硫酸"]     = new[] { "磺镪水", "发烟硫酸", "硫酸水" },
        ["盐酸"]     = new[] { "氢氯酸", "氯化氢溶液", "盐镪水" },
        ["氢氧化钠"] = new[] { "烧碱", "火碱", "苛性钠", "固碱" },
        ["氢氧化钾"] = new[] { "苛性钾", "钾碱" },
        ["氢氟酸"]   = new[] { "氟化氢溶液", "氟氢酸" },
        ["乙酸"]     = new[] { "醋酸", "冰醋酸", "冰乙酸" },
        ["氰化钠"]   = new[] { "山奈", "山奈钠", "氰化钠盐" },
        ["甲醛"]     = new[] { "福尔马林", "甲醛溶液", "蚁醛", "甲醛水" },
        ["苯乙烯"]   = new[] { "乙烯基苯", "苏合香烯", "ST" },
        ["三氯甲烷"] = new[] { "氯仿", "哥罗仿" },
        ["丙三醇"]   = new[] { "甘油" },
        ["氯化氢"]   = new[] { "氯化氢气", "盐酸气", "无水盐酸" },
        ["二氧化硫"] = new[] { "亚硫酸酐", "亚硫酐" },
        ["氧气"]     = new[] { "液氧", "氧气瓶", "O2" },
        ["硫磺"]     = new[] { "硫黄", "硫磺粉" },
        ["铝粉"]     = new[] { "银粉", "铝银粉" },
        ["氨溶液"]   = new[] { "氨水", "氢氧化铵", "阿摩尼亚水" },
    };

    // ── 危险类别种子 ──
    private static readonly Dictionary<string, (string Category, string Gb, string? Sub)[]> HazardSeed = new()
    {
        ["苯"]       = new[] { ("易燃液体", "GB 30000.7", "类别2"), ("致癌性", "GB 30000.23", "类别1A"), ("严重眼损伤/刺激", "GB 30000.20", "类别2"), ("特异性靶器官毒性 反复接触", "GB 30000.26", "类别1"), ("吸入危害", "GB 30000.27", "类别1") },
        ["甲苯"]     = new[] { ("易燃液体", "GB 30000.7", "类别2"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别2"), ("特异性靶器官毒性 反复接触", "GB 30000.26", "类别2"), ("吸入危害", "GB 30000.27", "类别1") },
        ["二甲苯"]   = new[] { ("易燃液体", "GB 30000.7", "类别3"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别2"), ("吸入危害", "GB 30000.27", "类别1") },
        ["甲醇"]     = new[] { ("易燃液体", "GB 30000.7", "类别2"), ("急性毒性", "GB 30000.18", "类别3（经口/经皮/吸入）"), ("特异性靶器官毒性 一次接触", "GB 30000.25", "类别1") },
        ["乙醇"]     = new[] { ("易燃液体", "GB 30000.7", "类别2") },
        ["丙酮"]     = new[] { ("易燃液体", "GB 30000.7", "类别2"), ("严重眼损伤/刺激", "GB 30000.20", "类别2"), ("特异性靶器官毒性 一次接触", "GB 30000.25", "类别3") },
        ["乙酸乙酯"] = new[] { ("易燃液体", "GB 30000.7", "类别2"), ("严重眼损伤/刺激", "GB 30000.20", "类别2") },
        ["环氧乙烷"] = new[] { ("易燃气体", "GB 30000.3", "类别1"), ("加压气体", "GB 30000.6", "液化气体"), ("致癌性", "GB 30000.23", "类别1B"), ("生殖细胞致突变性", "GB 30000.22", "类别1B"), ("急性毒性", "GB 30000.18", "类别3（吸入）") },
        ["过氧化氢"] = new[] { ("氧化性液体", "GB 30000.14", "类别1（≥60%）"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1A"), ("急性毒性", "GB 30000.18", "类别4（经口/经皮/吸入）") },
        ["硝酸"]     = new[] { ("氧化性液体", "GB 30000.14", "类别1"), ("金属腐蚀物", "GB 30000.17", "类别1"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1A"), ("急性毒性", "GB 30000.18", "类别3（吸入）") },
        ["硝酸铵"]   = new[] { ("氧化性固体", "GB 30000.15", "类别2"), ("爆炸物", "GB 30000.2", "非整体爆炸物（敏化后）") },
        ["高锰酸钾"] = new[] { ("氧化性固体", "GB 30000.15", "类别1"), ("急性毒性", "GB 30000.18", "类别4（经口）"), ("对水生环境危害", "GB 30000.28", "类别1") },
        ["重铬酸钠"] = new[] { ("氧化性固体", "GB 30000.15", "类别1"), ("致癌性", "GB 30000.23", "类别1B"), ("生殖细胞致突变性", "GB 30000.22", "类别1B"), ("急性毒性", "GB 30000.18", "类别2（经口）"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1B"), ("对水生环境危害", "GB 30000.28", "类别1") },
        ["氯"]       = new[] { ("加压气体", "GB 30000.6", "液化气体"), ("氧化性气体", "GB 30000.5", "类别1"), ("急性毒性", "GB 30000.18", "类别2（吸入）"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别2"), ("严重眼损伤/刺激", "GB 30000.20", "类别2"), ("对水生环境危害", "GB 30000.28", "类别1") },
        ["氨"]       = new[] { ("易燃气体", "GB 30000.3", "类别2"), ("加压气体", "GB 30000.6", "液化气体"), ("急性毒性", "GB 30000.18", "类别3（吸入）"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1B"), ("对水生环境危害", "GB 30000.28", "类别1") },
        ["硫化氢"]   = new[] { ("易燃气体", "GB 30000.3", "类别1"), ("加压气体", "GB 30000.6", "液化气体"), ("急性毒性", "GB 30000.18", "类别2（吸入）"), ("对水生环境危害", "GB 30000.28", "类别1") },
        ["乙炔"]     = new[] { ("易燃气体", "GB 30000.3", "类别1"), ("加压气体", "GB 30000.6", "溶解气体"), ("爆炸物", "GB 30000.2", "不安定爆炸物（无空气也可爆炸）") },
        ["氢气"]     = new[] { ("易燃气体", "GB 30000.3", "类别1"), ("加压气体", "GB 30000.6", "压缩气体") },
        ["硫酸"]     = new[] { ("皮肤腐蚀/刺激", "GB 30000.19", "类别1A"), ("金属腐蚀物", "GB 30000.17", "类别1"), ("严重眼损伤/刺激", "GB 30000.20", "类别1") },
        ["盐酸"]     = new[] { ("金属腐蚀物", "GB 30000.17", "类别1"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1B"), ("严重眼损伤/刺激", "GB 30000.20", "类别1"), ("特异性靶器官毒性 一次接触", "GB 30000.25", "类别3") },
        ["氢氧化钠"] = new[] { ("金属腐蚀物", "GB 30000.17", "类别1"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1A"), ("严重眼损伤/刺激", "GB 30000.20", "类别1") },
        ["氢氧化钾"] = new[] { ("金属腐蚀物", "GB 30000.17", "类别1"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1A"), ("急性毒性", "GB 30000.18", "类别4（经口）") },
        ["氢氟酸"]   = new[] { ("急性毒性", "GB 30000.18", "类别1（经皮）"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1A"), ("金属腐蚀物", "GB 30000.17", "类别1") },
        ["乙酸"]     = new[] { ("易燃液体", "GB 30000.7", "类别3"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1A"), ("金属腐蚀物", "GB 30000.17", "类别1") },
        ["氰化钠"]   = new[] { ("急性毒性", "GB 30000.18", "类别1（经口/经皮/吸入）"), ("对水生环境危害", "GB 30000.28", "类别1") },
        ["甲醛"]     = new[] { ("易燃液体", "GB 30000.7", "类别3（甲醛溶液）"), ("急性毒性", "GB 30000.18", "类别3（经口/经皮/吸入）"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1B"), ("致癌性", "GB 30000.23", "类别1B"), ("皮肤致敏", "GB 30000.21", "类别1") },
        ["苯乙烯"]   = new[] { ("易燃液体", "GB 30000.7", "类别3"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别2"), ("严重眼损伤/刺激", "GB 30000.20", "类别2"), ("致癌性", "GB 30000.23", "类别2"), ("特异性靶器官毒性 反复接触", "GB 30000.26", "类别1") },
        ["三氯甲烷"] = new[] { ("急性毒性", "GB 30000.18", "类别4（经口/经皮）"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别2"), ("严重眼损伤/刺激", "GB 30000.20", "类别2"), ("致癌性", "GB 30000.23", "类别2"), ("特异性靶器官毒性 反复接触", "GB 30000.26", "类别1") },
        ["氯化氢"]   = new[] { ("加压气体", "GB 30000.6", "液化气体"), ("急性毒性", "GB 30000.18", "类别3（吸入）"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1A"), ("金属腐蚀物", "GB 30000.17", "类别1") },
        ["二氧化硫"] = new[] { ("加压气体", "GB 30000.6", "液化气体"), ("急性毒性", "GB 30000.18", "类别3（吸入）"), ("皮肤腐蚀/刺激", "GB 30000.19", "类别1B"), ("金属腐蚀物", "GB 30000.17", "类别1") },
        ["氧气"]     = new[] { ("氧化性气体", "GB 30000.5", "类别1"), ("加压气体", "GB 30000.6", "压缩气体/冷冻液化气体") },
        ["硫磺"]     = new[] { ("易燃固体", "GB 30000.8", "类别2") },
        ["铝粉"]     = new[] { ("遇水放出易燃气体", "GB 30000.13", "类别2"), ("易燃固体", "GB 30000.8", "（粉尘有爆炸性）") },
        ["氨溶液"]   = new[] { ("皮肤腐蚀/刺激", "GB 30000.19", "类别1B"), ("严重眼损伤/刺激", "GB 30000.20", "类别1"), ("对水生环境危害", "GB 30000.28", "类别1") },
    };

    // ── 储存禁忌类别种子 ──
    private static readonly Dictionary<string, string[]> IncompatSeed = new()
    {
        ["苯"]       = new[] { "氧化剂", "强酸", "硝酸", "高锰酸钾" },
        ["甲苯"]     = new[] { "氧化剂", "强酸", "硝酸" },
        ["二甲苯"]   = new[] { "氧化剂", "强酸" },
        ["甲醇"]     = new[] { "氧化剂", "强酸", "硝酸", "过氧化物" },
        ["乙醇"]     = new[] { "氧化剂", "强酸", "硝酸" },
        ["丙酮"]     = new[] { "氧化剂", "强酸", "硝酸", "过氧化氢" },
        ["乙酸乙酯"] = new[] { "氧化剂", "强酸" },
        ["环氧乙烷"] = new[] { "酸", "碱", "氨", "胺类", "氧化剂", "金属氯化物" },
        ["过氧化氢"] = new[] { "易燃液体", "易燃固体", "还原剂", "有机物", "金属粉末", "丙酮", "乙醇", "甲醇" },
        ["硝酸"]     = new[] { "易燃液体", "易燃固体", "有机物", "还原剂", "碱", "金属粉末", "氰化物", "甲醇", "乙醇", "丙酮", "甲苯", "苯", "乙酸" },
        ["硝酸铵"]   = new[] { "易燃固体", "有机物", "还原剂", "金属粉末", "硫磺", "铝粉", "易燃液体" },
        ["高锰酸钾"] = new[] { "易燃液体", "易燃固体", "有机物", "甘油", "乙醇", "还原剂", "硫酸", "金属粉末" },
        ["重铬酸钠"] = new[] { "易燃液体", "易燃固体", "有机物", "还原剂" },
        ["氯"]       = new[] { "氨", "氢", "乙炔", "烃类", "金属粉末", "还原剂", "可燃物" },
        ["氨"]       = new[] { "氧化剂", "卤素", "酸", "次氯酸盐", "氯", "氯化氢", "溴", "碘", "环氧乙烷" },
        ["硫化氢"]   = new[] { "氧化剂", "硝酸", "过氧化氢", "氯" },
        ["乙炔"]     = new[] { "氧", "氧化剂", "卤素", "铜", "银", "汞及其化合物" },
        ["氢气"]     = new[] { "氧化剂", "氧", "卤素", "氯" },
        ["硫酸"]     = new[] { "易燃液体", "碱", "有机物", "还原剂", "金属粉末", "氰化物", "高锰酸钾" },
        ["盐酸"]     = new[] { "碱", "氧化剂", "氰化物", "金属", "胺类", "氨", "氢氧化钠" },
        ["氢氧化钠"] = new[] { "酸", "氯化氢", "铝", "锌", "锡", "硝基化合物", "氰化氢" },
        ["氢氧化钾"] = new[] { "酸", "氯化氢", "铝", "锌", "锡" },
        ["氢氟酸"]   = new[] { "碱", "氨", "玻璃", "硅酸盐", "金属" },
        ["乙酸"]     = new[] { "氧化剂", "硝酸", "过氧化氢", "高锰酸钾", "铬酸", "碱", "氢氧化钠" },
        ["氰化钠"]   = new[] { "酸", "氧化剂", "硝酸", "盐酸", "硫酸", "水（遇水可能释放HCN）" },
        ["甲醛"]     = new[] { "氧化剂", "硝酸", "过氧化氢", "胺类", "氨" },
        ["苯乙烯"]   = new[] { "过氧化物", "氧化剂", "强酸", "过氧化氢", "聚合引发剂" },
        ["三氯甲烷"] = new[] { "碱", "碱金属", "铝" },
        ["丙三醇"]   = new[] { "氧化剂", "高锰酸钾", "硝酸", "铬酸", "过氧化物" },
        ["氯化氢"]   = new[] { "碱", "胺类", "氨", "氢氧化钠", "活泼金属" },
        ["二氧化硫"] = new[] { "氨", "碱", "强还原剂" },
        ["氧气"]     = new[] { "易燃物", "还原剂", "油类", "乙炔", "氢" },
        ["硫磺"]     = new[] { "氧化剂", "硝酸铵", "高锰酸钾", "氯酸盐", "硝酸盐" },
        ["铝粉"]     = new[] { "氧化剂", "酸", "碱", "硝酸铵", "高锰酸钾", "卤代烃", "水" },
        ["氨溶液"]   = new[] { "酸", "盐", "卤素", "次氯酸盐", "氯", "氢氟酸", "氯化氢" },
    };

    // ── 精确禁忌配对（与 migration 002 的 chemical_incompatibilities 逐条对应）──
    private static readonly (string A, string B, bool Compatible, string Reason, string Reg)[] IncompatRuleSeed =
    {
        ("苯",       "丙酮",   true,  "同类易燃液体可同库分区存放",                                    "GB 15603"),
        ("硝酸",     "乙酸",   false, "氧化剂与易燃液体严禁同库",                                      "GB 15603"),
        ("氢氧化钠", "盐酸",   false, "酸碱中和放热反应，严禁同库混存",                                 "GB 15603"),
        ("甲醇",     "硝酸",   false, "氧化剂与易燃液体严禁同库，可能引发火灾爆炸",                    "GB 15603"),
        ("过氧化氢", "丙酮",   false, "强氧化剂与易燃液体严禁同库，过氧化氢遇有机物剧烈分解",           "GB 15603"),
        ("氨",       "氯化氢", false, "酸性气体与碱性气体混合产生氯化铵烟雾，严禁同区",                 "GB 15603"),
        ("氯",       "氨",     false, "氯与氨反应生成三氯化氮(易爆)，严禁同区混存",                    "GB 15603"),
        ("甲苯",     "二甲苯", true,  "同类易燃液体（均为C类）可同库分区存放",                          "GB 15603"),
        ("高锰酸钾", "丙三醇", false, "强氧化剂与易燃液体(甘油)严禁混存，接触可能自燃",                ""),
        ("环氧乙烷", "氨",     false, "环氧乙烷遇氨可能发生聚合反应放热爆炸",                          ""),
        ("丙酮",     "乙醇",   true,  "同类易燃液体可同库分区存放",                                    "GB 15603"),
        ("硝酸铵",   "硫磺",   false, "硝酸铵为强氧化剂，硫磺为易燃固体，混合可形成爆炸性混合物",        ""),
        ("氢氟酸",   "氨溶液", false, "酸碱中和放热，产生有毒氟化铵，严禁混存",                        ""),
        ("苯乙烯",   "过氧化氢", false, "过氧化物可引发苯乙烯剧烈聚合放热，存在爆炸风险",              ""),
        ("硫化氢",   "二氧化硫", true, "同属酸性气体(还原性)，可同库但需有效隔离和通风",               ""),
        ("乙炔",     "氧气",   false, "易燃气体与助燃气体严禁同库，乙炔遇氧爆炸极限极宽(2.5-82%)",      "GB 15603"),
        ("硝酸",     "盐酸",   false, "硝酸+盐酸=王水，混合放热并产生氯气/亚硝酰氯剧毒气体，严禁同库混存", "GB 15603"),
        ("氰化钠",   "盐酸",   false, "氰化钠遇酸产生剧毒氰化氢(HCN)气体，严禁共库",                   ""),
        ("铝粉",     "硝酸铵", false, "金属粉末与氧化剂混合可形成爆炸性混合物，严禁混存",               ""),
        ("三氯甲烷", "丙酮",   true,  "无明确配伍禁忌，可同库分区存放",                                ""),
    };

    // ── 安全距离种子（20 条，与 migration 002 一致）──
    private static readonly (string Pair, double Meters, string Reg)[] DistanceSeed =
    {
        ("储罐-储罐",           15,  "GB 50160"),
        ("储罐-建筑",           25,  "GB 50160"),
        ("储罐-消防通道",       15,  "GB 50160"),
        ("储罐-厂区边界",       30,  "GB 50160"),
        ("液化烃储罐-储罐",     20,  "GB 50160"),
        ("液化烃储罐-厂区围墙", 35,  "GB 50160"),
        ("甲类仓库-建筑",       20,  "GB 50160 / GB 50016"),
        ("甲类仓库-明火点",     30,  "GB 50160"),
        ("甲类仓库-办公楼",     30,  "GB 50160"),
        ("甲类工艺装置-重要设施", 30, "GB 50160"),
        ("甲类工艺装置-明火点", 30,  "GB 50160"),
        ("乙炔气柜-建筑",       25,  "GB 50160"),
        ("氨罐-厂外道路",       20,  "GB 50160"),
        ("氢气长管拖车-明火点", 25,  "GB 50160"),
        ("消防站-甲类装置",     15,  "GB 50160"),
        ("氯气储存区-居住区",   200, "GB 50160（依据重大危险源等级）"),
        ("液化烃储罐-办公楼",   35,  "GB 50160"),
        ("易燃液体储罐-装卸站", 15,  "GB 50160"),
        ("甲类仓库-厂内道路",   15,  "GB 50016"),
        ("甲类厂房-甲类厂房",   12,  "GB 50016"),
        // ── 评测集 E001-E008 专用条目（旧 Stub 5268b27f 种子，migration 002 未收录）──
        ("乙炔气柜-办公楼",     25,  "GB 50160"),
        ("甲类仓库-民用建筑",   25,  "GB 50016-2014"),
        ("甲类仓库-明火作业点", 30,  "GB 50016-2014"),
    };

    // ── 法规版本种子（8 条，与 migration 002 一致）──
    private static readonly (string Num, string Title, string Ver, bool Full, string[] Dep)[] RegulationSeed =
    {
        ("GB 15603",   "常用化学危险品贮存通则",                       "2022",                true,  new[] { "1995" }),
        ("GB 30000",   "化学品分类和标签规范",                         "2013",                true,  Array.Empty<string>()),
        ("GB 30000.1", "化学品分类和标签规范 第1部分:通则",             "2024",                true,  new[] { "2013" }),
        ("GB 50160",   "石油化工企业设计防火规范",                     "2008（2018局部修订）", false, Array.Empty<string>()),
        ("GB 50016",   "建筑设计防火规范",                             "2014（2018局部修订）", false, new[] { "2006" }),
        ("GB 18218",   "危险化学品重大危险源辨识",                     "2018",                false, new[] { "2009" }),
        ("GB 30871",   "危险化学品企业特殊作业安全规范",               "2022",                true,  new[] { "2014" }),
        ("JT/T 617",   "危险货物道路运输规则",                         "2018",                false, Array.Empty<string>()),
    };

    public StubChemicalKnowledgeGraph()
    {
        _substances = new List<ChemicalSubstance>();
        _safetyDistances = new List<SafetyDistanceRule>();
        _regulations = new List<RegulationVersion>();
        _incompatRules = new List<StorageIncompatibilityRule>();

        foreach (var s in SubstanceSeed)
        {
            var sub = new ChemicalSubstance
            {
                Name = s.Name,
                NameEn = s.En,
                CasNumber = s.Cas,
                UnNumber = s.Un,
                Formula = s.Formula,
                PhysicalState = s.State,
                FlashPointC = s.Fp,
                BoilingPointC = s.Bp,
                MajorHazardThresholdTons = s.Threshold,
            };
            if (AliasSeed.TryGetValue(s.Name, out var aliases))
                sub.Aliases.AddRange(aliases);
            if (HazardSeed.TryGetValue(s.Name, out var hazards))
                sub.HazardCategories.AddRange(hazards.Select(h => new HazardCategoryRef { Category = h.Category, GbStandard = h.Gb, SubCategory = h.Sub }));
            if (IncompatSeed.TryGetValue(s.Name, out var incompats))
                sub.IncompatibleWith.AddRange(incompats);
            _substances.Add(sub);
        }

        _safetyDistances.AddRange(DistanceSeed.Select(d => new SafetyDistanceRule
        {
            FacilityPair = d.Pair,
            MinDistanceMeters = d.Meters,
            RegulationRef = d.Reg,
        }));

        _regulations.AddRange(RegulationSeed.Select(r => new RegulationVersion
        {
            RegulationNumber = r.Num,
            Title = r.Title,
            CurrentVersion = r.Ver,
            HasFullText = r.Full,
            DeprecatedVersions = r.Dep.ToList(),
        }));

        _incompatRules.AddRange(IncompatRuleSeed.Select(r => new StorageIncompatibilityRule
        {
            SubstanceA = r.A,
            SubstanceB = r.B,
            IsCompatible = r.Compatible,
            Reason = r.Reason,
            RegulationRef = r.Reg,
        }));
    }

    public ChemicalSubstance? Lookup(string name)
    {
        if (string.IsNullOrWhiteSpace(name)) return null;
        var trimmed = name.Trim();
        var standard = _substances.FirstOrDefault(s =>
            string.Equals(s.Name, trimmed, StringComparison.OrdinalIgnoreCase) ||
            s.Aliases.Any(a => string.Equals(a, trimmed, StringComparison.OrdinalIgnoreCase)));
        return standard;
    }

    public ChemicalSubstance? LookupByCas(string casNumber)
        => _substances.FirstOrDefault(s => string.Equals(s.CasNumber, casNumber, StringComparison.OrdinalIgnoreCase));

    public List<ChemicalSubstance> Search(string keyword, int maxResults = 5)
        => _substances.Where(s => s.Name.Contains(keyword, StringComparison.OrdinalIgnoreCase)
                                  || s.Aliases.Any(a => a.Contains(keyword, StringComparison.OrdinalIgnoreCase))
                                  || s.CasNumber.Contains(keyword, StringComparison.OrdinalIgnoreCase))
                      .Take(maxResults).ToList();

    public IReadOnlyList<ChemicalSubstance> GetAll() => _substances;

    public int Count => _substances.Count;

    public StorageIncompatibilityRule? CheckCompatibility(string substanceA, string substanceB)
    {
        var a = Lookup(substanceA);
        var b = Lookup(substanceB);
        if (a == null || b == null) return null;

        // 精确规则优先（双向匹配）
        var exact = _incompatRules.FirstOrDefault(r =>
            (string.Equals(r.SubstanceA, a.Name, StringComparison.OrdinalIgnoreCase) &&
             string.Equals(r.SubstanceB, b.Name, StringComparison.OrdinalIgnoreCase)) ||
            (string.Equals(r.SubstanceA, b.Name, StringComparison.OrdinalIgnoreCase) &&
             string.Equals(r.SubstanceB, a.Name, StringComparison.OrdinalIgnoreCase)));
        if (exact != null) return exact;

        // 类别级判定：A 的禁忌类别 ∩ B 的危险类别（双向）
        foreach (var incat in a.IncompatibleWith)
        {
            foreach (var hc in b.HazardCategories)
            {
                if (hc.Category.Contains(incat, StringComparison.OrdinalIgnoreCase)
                    || incat.Contains(hc.Category, StringComparison.OrdinalIgnoreCase))
                {
                    return new StorageIncompatibilityRule
                    {
                        SubstanceA = a.Name,
                        SubstanceB = b.Name,
                        IsCompatible = false,
                        Reason = $"储存禁忌类别「{incat}」与危险类别「{hc.Category}」冲突",
                        RegulationRef = "GB 15603",
                    };
                }
            }
        }
        foreach (var incat in b.IncompatibleWith)
        {
            foreach (var hc in a.HazardCategories)
            {
                if (hc.Category.Contains(incat, StringComparison.OrdinalIgnoreCase)
                    || incat.Contains(hc.Category, StringComparison.OrdinalIgnoreCase))
                {
                    return new StorageIncompatibilityRule
                    {
                        SubstanceA = a.Name,
                        SubstanceB = b.Name,
                        IsCompatible = false,
                        Reason = $"储存禁忌类别「{incat}」与危险类别「{hc.Category}」冲突",
                        RegulationRef = "GB 15603",
                    };
                }
            }
        }

        return null; // 无规则命中，走 LLM 兜底路径
    }

    public SafetyDistanceRule? GetSafetyDistance(string facilityPair)
    {
        if (string.IsNullOrWhiteSpace(facilityPair)) return null;
        var exact = _safetyDistances.FirstOrDefault(d =>
            string.Equals(d.FacilityPair, facilityPair, StringComparison.OrdinalIgnoreCase));
        if (exact != null) return exact;

        // 部分匹配：输入是规则子串（如 "液化烃储罐" → "液化烃储罐-厂区围墙"）
        return _safetyDistances.FirstOrDefault(d =>
            d.FacilityPair.Contains(facilityPair, StringComparison.OrdinalIgnoreCase)
            || facilityPair.Contains(d.FacilityPair, StringComparison.OrdinalIgnoreCase));
    }

    public IReadOnlyList<SafetyDistanceRule> GetAllSafetyDistances() => _safetyDistances;

    public RegulationVersion? GetRegulationVersion(string number)
    {
        if (string.IsNullOrWhiteSpace(number)) return null;
        var normalized = number.Trim().Replace(" ", "", StringComparison.Ordinal);

        var exact = _regulations.FirstOrDefault(r =>
            string.Equals(r.RegulationNumber, number, StringComparison.OrdinalIgnoreCase));
        if (exact != null) return exact;

        // 编号标准化后匹配（"GB15603" → "GB 15603"）
        var byNormalized = _regulations.FirstOrDefault(r =>
            string.Equals(r.RegulationNumber.Replace(" ", "", StringComparison.Ordinal), normalized, StringComparison.OrdinalIgnoreCase));
        if (byNormalized != null) return byNormalized;

        // 部分匹配（"30871" → "GB 30871"）
        return _regulations.FirstOrDefault(r =>
            r.RegulationNumber.Contains(normalized, StringComparison.OrdinalIgnoreCase)
            || normalized.Contains(r.RegulationNumber.Replace(" ", "", StringComparison.Ordinal), StringComparison.OrdinalIgnoreCase));
    }

    public IReadOnlyList<RegulationVersion> GetAllRegulationVersions() => _regulations;

    public void AddSubstance(ChemicalSubstance substance) => _substances.Add(substance);

    public void AddAlias(string substanceName, string alias)
        => Lookup(substanceName)?.Aliases.Add(alias);

    public void EnsureInitialized() { }
}
