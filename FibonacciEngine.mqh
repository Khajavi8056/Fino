//+------------------------------------------------------------------+
//|                                           FibonacciEngine.mqh |
//|        A Professional Fibonacci Structure & Analysis Library     |
//|                                     Copyright 2025, HipoAlgoritm |
//+------------------------------------------------------------------+
#property copyright "Mohammad Khajavi"
#property link      "https://HipoAlgoritm.com"
#property version   "4.00" // نسخه نهایی، کامل و بازبینی شده
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//|        >>>>>>>>> ورودی‌های کتابخانه موتور فیبوناچی <<<<<<<<<        |
//|                                                                  |
//+------------------------------------------------------------------+

//--- گروه: تنظیمات اصلی استراتژی فیبوناچی
input group "Fibonacci Strategy Settings";
enum ENUM_FIBO_STRATEGY_MODE
{
    MODE_BOTH,              // هر دو روش فعال
    MODE_FLOATING_ONLY,     // فقط روش شناور (نوع ۱)
    MODE_EXTENSION_ONLY     // فقط روش اکستنشن (نوع ۲)
};
input ENUM_FIBO_STRATEGY_MODE InpStrategyMode = MODE_BOTH; // انتخاب حالت کار کتابخانه

//--- گروه: تنظیمات شکست ساختار (BOS)
input group "Break of Structure (BOS) Settings";
enum ENUM_BREAK_TYPE
{
    BREAK_SIMPLE = 0,       // شکست ساده (فقط عبور قیمت)
    BREAK_CONFIRMED = 1     // شکست با تأییدیه (بسته شدن کندل)
};
input ENUM_BREAK_TYPE InpBreakType = BREAK_CONFIRMED; // نوع شکست
input int             InpConfirmationCandles = 1;   // تعداد کندل‌های تأیید برای شکست

enum ENUM_MAIN_PEAKVALLEY_MODE
{
    MODE_PEAK_TIME,         // مبنای انتخاب: بر اساس زمان تشکیل سقف/کف
    MODE_BREAK_TIME         // مبنای انتخاب: بر اساس زمان شکست سقف/کف
};
input ENUM_MAIN_PEAKVALLEY_MODE InpMainPeakValleyMode = MODE_BREAK_TIME; // مبنای انتخاب ساختار اصلی

//--- گروه: تنظیمات اندیکاتور Fineflow
input group "Fineflow Indicator Settings";
input ENUM_TIMEFRAMES InpFineflow_Timeframe = PERIOD_CURRENT; // تایم فریم اندیکاتور
input bool InpFineflow_EnforceStrictSequence = true; // اعمال توالی اجباری سقف/کف
enum E_DetectionMethod
{
    METHOD_SIMPLE,
    METHOD_SEQUENTIAL,
    METHOD_POWER_SWING,
    METHOD_ZIGZAG
};
input E_DetectionMethod InpFineflow_DetectionMethod = METHOD_POWER_SWING;
input int InpFineflow_Lookback = 3;
input int InpFineflow_AtrPeriod = 14;
input double InpFineflow_AtrMultiplier = 2.5;

//--- گروه: تنظیمات فیبوناچی و نمایش
input group "Fibonacci & Display Settings";
input string InpFiboLevelsToShow = "0,23.6,38.2,50,61.8,78.6,100,150,200"; // سطوح نمایشی فیبوناچی
input double InpEntryZone_Start = 50.0;     // شروع ناحیه ورود
input double InpEntryZone_End   = 61.8;     // پایان ناحیه ورود
input color  InpEntryZone_Color = C'34,139,34,70'; // رنگ ناحیه ورود (سبز شفاف)
input bool   InpShowBOS         = true;     // نمایش لیبل "BOS"
input bool   InpShowAnchorBlock = true;     // نمایش اوردر بلاک لنگرگاه
input color  InpAnchorBlock_Color = clrDarkSlateGray; // رنگ اوردر بلاک لنگرگاه
input bool   InpShowStatusLabel = true;     // نمایش لیبل وضعیت

//+------------------------------------------------------------------+
//|                                                                  |
//|               ساختارها و شمارنده‌های کتابخانه (Structs & Enums)      |
//|                                                                  |
//+------------------------------------------------------------------+

enum ENUM_FIBO_ENGINE_STATE
{
    STATE_SCOUTING, STATE_AWAITING_TRIGGER_1, STATE_FIBO_1_ACTIVE,
    STATE_FIBO_2_ACTIVE, STATE_IN_ENTRY_ZONE, STATE_ANALYSIS_COMPLETE
};

enum ENUM_FIBO_STATUS
{
    STATUS_NO_FIBO, STATUS_AWAITING_ENTRY, STATUS_IN_ENTRY_ZONE,
    STATUS_INVALIDATED_OVERRIDDEN, STATUS_INVALIDATED_ANCHOR_BROKEN,
    STATUS_INVALIDATED_ZONE_PASSED
};

enum ENUM_TRADE_DIRECTION { DIRECTION_BUY, DIRECTION_SELL };

struct PeakValley
{
    double   price;
    datetime time;
    int      index;
    string   id;
};

struct MainPeakValley
{
    double   peakPrice;
    datetime peakTime;
    datetime breakTime;
    string   id;
    bool     isCeiling;
};

struct ActiveFiboInfo
{
    bool       isActive;
    string     fiboName;
    double     p0_price;
    datetime   p0_time;
    double     p100_price;
    datetime   p100_time;
    PeakValley minorCorrectivePoint;
};

//+------------------------------------------------------------------+
//|                                                                  |
//|                  کلاس اصلی موتور فیبوناچی (CFibonacciEngine)        |
//|                                                                  |
//+------------------------------------------------------------------+
class CFibonacciEngine
{
private:
    ENUM_FIBO_ENGINE_STATE m_state;
    long                   m_magicNumber;
    string                 m_chartPrefix;
    int                    m_handleFineflow;
    PeakValley             m_ceilings[50];
    PeakValley             m_valleys[50];
    int                    m_ceilings_total;
    int                    m_valleys_total;
    MainPeakValley         m_lastMainStructure;
    PeakValley             m_anchorPoint;
    ActiveFiboInfo         m_activeFibo;
    datetime               m_lastCandleTime;

    void                   ScoutForStructure();
    void                   ManageDataArrays(const PeakValley &newPeak, bool isCeiling);
    bool                   DetectBreak(const PeakValley &structure, bool isCeiling, double &breakPrice, datetime &breakTime);
    void                   IdentifyAnchorPoint();
    void                   RunTheGate();
    void                   ActivateFiboType1();
    void                   ActivateFiboType2();
    void                   UpdateFiboType1();
    void                   CheckConditions();
    void                   ResetAnalysis(string reason);
    void                   DrawStatusLabel();
    void                   DrawMainStructure();
    void                   DrawAnchorBlock();
    void                   DrawFibonacci();
    void                   DrawEntryZone();
    void                   ClearAllGraphics(string reason);
    void                   RemovePeakValleyFromArray(string id, bool isCeiling);
    bool                   IsNewStructureDominant(const PeakValley &structure, datetime breakTime);

public:
    void                   CFibonacciEngine();
    void                   ~CFibonacciEngine();
    bool                   Init(long expert_magic_number);
    void                   Deinit();
    void                   OnTick();
    bool                   AnalyzeAndDrawFibo(ENUM_TRADE_DIRECTION direction);
    ENUM_FIBO_STATUS       GetFiboStatus();
};

//+------------------------------------------------------------------+
//|                  پیاده‌سازی توابع کلاس (Implementation)             |
//+------------------------------------------------------------------+

void CFibonacciEngine::CFibonacciEngine()
{
    m_state = STATE_SCOUTING;
    m_handleFineflow = INVALID_HANDLE;
    m_magicNumber = 0;
    m_lastCandleTime = 0;
    m_ceilings_total = 0;
    m_valleys_total = 0;
    m_lastMainStructure.id = "";
    m_activeFibo.isActive = false;
    ArrayInitialize(m_ceilings, 0);
    ArrayInitialize(m_valleys, 0);
}

void CFibonacciEngine::~CFibonacciEngine() {}

bool CFibonacciEngine::Init(long expert_magic_number)
{
    m_magicNumber = expert_magic_number;
    m_chartPrefix = "FiboEngine_" + (string)m_magicNumber + "_" + (string)ChartID() + "_";
    m_handleFineflow = iCustom(_Symbol, InpFineflow_Timeframe, "fineflow", InpFineflow_EnforceStrictSequence, InpFineflow_DetectionMethod, InpFineflow_Lookback, InpFineflow_AtrPeriod, InpFineflow_AtrMultiplier);
    if(m_handleFineflow == INVALID_HANDLE)
    {
        Print("خطا: کتابخانه فیبوناچی نتوانست اندیکاتور fineflow را لود کند!");
        return false;
    }
    Print("موتور فیبوناچی با موفقیت راه‌اندازی شد.");
    return true;
}

void CFibonacciEngine::Deinit()
{
    if(m_handleFineflow != INVALID_HANDLE) IndicatorRelease(m_handleFineflow);
    ClearAllGraphics("Deinitialization");
    Print("موتور فیبوناچی با موفقیت غیرفعال شد.");
}

void CFibonacciEngine::OnTick()
{
    datetime currentTime = iTime(_Symbol, _Period, 0);
    if(currentTime == m_lastCandleTime) return;
    m_lastCandleTime = currentTime;

    switch(m_state)
    {
        case STATE_SCOUTING:
            ScoutForStructure();
            break;
        case STATE_AWAITING_TRIGGER_1:
        {
            double price = m_lastMainStructure.isCeiling ? iHigh(_Symbol, _Period, 1) : iLow(_Symbol, _Period, 1);
            double triggerPrice = m_activeFibo.minorCorrectivePoint.price;
            bool triggerMet = m_lastMainStructure.isCeiling ? (price > triggerPrice) : (price < triggerPrice);
            if(triggerMet) ActivateFiboType1();
            CheckConditions();
            break;
        }
        case STATE_FIBO_1_ACTIVE:
            UpdateFiboType1();
            CheckConditions();
            break;
        case STATE_FIBO_2_ACTIVE:
        case STATE_IN_ENTRY_ZONE:
            CheckConditions();
            break;
    }
    if(InpShowStatusLabel) DrawStatusLabel();
}

void CFibonacciEngine::ScoutForStructure()
{
    double peakBuffer[], valleyBuffer[];
    datetime timeBuffer[];
    int dataToCopy = 200;

    if(CopyBuffer(m_handleFineflow, 0, 1, dataToCopy, peakBuffer) <= 0 ||
       CopyBuffer(m_handleFineflow, 1, 1, dataToCopy, valleyBuffer) <= 0 ||
       CopyTime(_Symbol, InpFineflow_Timeframe, 1, dataToCopy, timeBuffer) <= 0)
        return;

    ArraySetAsSeries(peakBuffer, true);
    ArraySetAsSeries(valleyBuffer, true);
    ArraySetAsSeries(timeBuffer, true);

    for(int i = 0; i < dataToCopy; i++)
    {
        if(peakBuffer[i] > 0) ManageDataArrays({peakBuffer[i], timeBuffer[i], iBarShift(_Symbol, _Period, timeBuffer[i]), "C_"+TimeToString(timeBuffer[i])}, true);
        if(valleyBuffer[i] > 0) ManageDataArrays({valleyBuffer[i], timeBuffer[i], iBarShift(_Symbol, _Period, timeBuffer[i]), "V_"+TimeToString(timeBuffer[i])}, false);
    }

    for(int i = 0; i < m_ceilings_total; i++)
    {
        double breakPrice; datetime breakTime;
        if(DetectBreak(m_ceilings[i], true, breakPrice, breakTime))
        {
            if(IsNewStructureDominant(m_ceilings[i], breakTime))
            {
                if(m_activeFibo.isActive) ResetAnalysis("ساختار جدید صعودی یافت شد.");
                m_lastMainStructure = {m_ceilings[i].price, m_ceilings[i].time, breakTime, m_ceilings[i].id, true};
                IdentifyAnchorPoint();
                DrawMainStructure();
                RemovePeakValleyFromArray(m_lastMainStructure.id, true);
                return;
            }
        }
    }
    for(int i = 0; i < m_valleys_total; i++)
    {
        double breakPrice; datetime breakTime;
        if(DetectBreak(m_valleys[i], false, breakPrice, breakTime))
        {
             if(IsNewStructureDominant(m_valleys[i], breakTime))
             {
                if(m_activeFibo.isActive) ResetAnalysis("ساختار جدید نزولی یافت شد.");
                m_lastMainStructure = {m_valleys[i].price, m_valleys[i].time, breakTime, m_valleys[i].id, false};
                IdentifyAnchorPoint();
                DrawMainStructure();
                RemovePeakValleyFromArray(m_lastMainStructure.id, false);
                return;
             }
        }
    }
}

void CFibonacciEngine::ManageDataArrays(const PeakValley &newPoint, bool isCeiling)
{
    PeakValley &arr[] = isCeiling ? m_ceilings : m_valleys;
    int &total = isCeiling ? m_ceilings_total : m_valleys_total;

    for(int i = 0; i < total; i++) if(arr[i].time == newPoint.time) return;

    if(total < 50)
    {
        arr[total] = newPoint;
        total++;
    }
    else
    {
        ArrayCopy(arr, arr, 0, 1, 49);
        arr[49] = newPoint;
    }
}

bool CFibonacciEngine::DetectBreak(const PeakValley &structure, bool isCeiling, double &breakPrice, datetime &breakTime)
{
    if(structure.time >= iTime(_Symbol, _Period, 1)) return false;

    if(InpBreakType == BREAK_SIMPLE)
    {
        double price = isCeiling ? iHigh(_Symbol, _Period, 1) : iLow(_Symbol, _Period, 1);
        if((isCeiling && price > structure.price) || (!isCeiling && price < structure.price))
        {
            breakPrice = price;
            breakTime = iTime(_Symbol, _Period, 1);
            return true;
        }
    }
    else
    {
        double price = iClose(_Symbol, _Period, 1);
        if((isCeiling && price > structure.price) || (!isCeiling && price < structure.price))
        {
            breakPrice = price;
            breakTime = iTime(_Symbol, _Period, 1);
            return true;
        }
    }
    return false;
}

void CFibonacciEngine::IdentifyAnchorPoint()
{
    int startIndex = iBarShift(_Symbol, _Period, m_lastMainStructure.breakTime);
    int endIndex = iBarShift(_Symbol, _Period, m_lastMainStructure.peakTime);
    if(startIndex < 0 || endIndex < 0 || startIndex > endIndex) return;

    int count = endIndex - startIndex + 1;
    int extremeIndex = m_lastMainStructure.isCeiling ? iLowest(_Symbol, _Period, MODE_LOW, count, startIndex) : iHighest(_Symbol, _Period, MODE_HIGH, count, startIndex);
    
    if(extremeIndex != -1)
    {
        m_anchorPoint.price = m_lastMainStructure.isCeiling ? iLow(_Symbol, _Period, extremeIndex) : iHigh(_Symbol, _Period, extremeIndex);
        m_anchorPoint.time = iTime(_Symbol, _Period, extremeIndex);
        m_anchorPoint.index = extremeIndex;
        DrawAnchorBlock();
    }
}

bool CFibonacciEngine::AnalyzeAndDrawFibo(ENUM_TRADE_DIRECTION direction)
{
    if(m_lastMainStructure.id == "") return false;
    if((direction == DIRECTION_BUY && !m_lastMainStructure.isCeiling) || (direction == DIRECTION_SELL && m_lastMainStructure.isCeiling)) return false;
    
    RunTheGate();
    return true;
}

void CFibonacciEngine::RunTheGate()
{
    bool isType1ConditionMet = false;
    int startIndex = m_anchorPoint.index;
    int endIndex = iBarShift(_Symbol, _Period, m_lastMainStructure.breakTime);
    
    if(startIndex > 0 && endIndex > 0 && startIndex < endIndex)
    {
        PeakValley &opposite_arr[] = m_lastMainStructure.isCeiling ? m_valleys : m_ceilings;
        int opposite_total = m_lastMainStructure.isCeiling ? m_valleys_total : m_ceilings_total;
        
        for(int i=0; i < opposite_total; i++)
        {
            if(opposite_arr[i].index > startIndex && opposite_arr[i].index < endIndex)
            {
                m_activeFibo.minorCorrectivePoint = opposite_arr[i];
                double p0 = m_anchorPoint.price;
                double p100 = m_activeFibo.minorCorrectivePoint.price;
                double high_range = MathMax(p0, p100);
                double low_range = MathMin(p0, p100);
                
                // Find lowest low / highest high after the corrective point
                int search_end_index = iBarShift(_Symbol, _Period, m_lastMainStructure.breakTime);
                int search_start_index = m_activeFibo.minorCorrectivePoint.index;
                int count = search_end_index - search_start_index + 1;
                
                if(count > 0)
                {
                    int extreme_idx = m_lastMainStructure.isCeiling ? iLowest(_Symbol, _Period, MODE_LOW, count, search_start_index) : iHighest(_Symbol, _Period, MODE_HIGH, count, search_start_index);
                    if(extreme_idx > 0)
                    {
                        double extreme_price = m_lastMainStructure.isCeiling ? iLow(_Symbol, _Period, extreme_idx) : iHigh(_Symbol, _Period, extreme_idx);
                        double zoneStart = p0 + (p100 - p0) * (InpEntryZone_Start / 100.0);
                        double zoneEnd = p0 + (p100 - p0) * (InpEntryZone_End / 100.0);
                        if(zoneStart > zoneEnd) { double temp=zoneStart; zoneStart=zoneEnd; zoneEnd=temp; }
                        
                        if(extreme_price >= zoneStart && extreme_price <= zoneEnd)
                        {
                            isType1ConditionMet = true;
                            break;
                        }
                    }
                }
            }
        }
    }

    if(isType1ConditionMet && (InpStrategyMode == MODE_BOTH || InpStrategyMode == MODE_FLOATING_ONLY))
    {
        m_state = STATE_AWAITING_TRIGGER_1;
    }
    else if(InpStrategyMode == MODE_BOTH || InpStrategyMode == MODE_EXTENSION_ONLY)
    {
        ActivateFiboType2();
    }
}

void CFibonacciEngine::ActivateFiboType1()
{
    m_state = STATE_FIBO_1_ACTIVE;
    m_activeFibo.isActive = true;
    m_activeFibo.fiboName = m_chartPrefix + "Fibo_Float_" + m_lastMainStructure.id;
    m_activeFibo.p0_price = m_anchorPoint.price;
    m_activeFibo.p0_time = m_anchorPoint.time;
    m_activeFibo.p100_price = m_activeFibo.minorCorrectivePoint.price;
    m_activeFibo.p100_time = m_activeFibo.minorCorrectivePoint.time;
    DrawFibonacci();
    DrawEntryZone();
}

void CFibonacciEngine::ActivateFiboType2()
{
    m_state = STATE_FIBO_2_ACTIVE;
    m_activeFibo.isActive = true;
    m_activeFibo.fiboName = m_chartPrefix + "Fibo_Ext_" + m_lastMainStructure.id;
    m_activeFibo.p0_price = m_anchorPoint.price;
    m_activeFibo.p0_time = m_anchorPoint.time;
    m_activeFibo.p100_price = m_lastMainStructure.peakPrice;
    m_activeFibo.p100_time = m_lastMainStructure.peakTime;
    DrawFibonacci();
    DrawEntryZone();
}

void CFibonacciEngine::UpdateFiboType1()
{
    if(!m_activeFibo.isActive) return;
    double new_p100_price = m_lastMainStructure.isCeiling ? iHigh(_Symbol, _Period, 1) : iLow(_Symbol, _Period, 1);
    if((m_lastMainStructure.isCeiling && new_p100_price > m_activeFibo.p100_price) || (!m_lastMainStructure.isCeiling && new_p100_price < m_activeFibo.p100_price))
    {
        m_activeFibo.p100_price = new_p100_price;
        m_activeFibo.p100_time = iTime(_Symbol, _Period, 1);
        DrawFibonacci();
        DrawEntryZone();
    }
}

void CFibonacciEngine::CheckConditions()
{
    if(m_anchorPoint.time == 0) return;
    double high = iHigh(_Symbol, _Period, 1);
    double low = iLow(_Symbol, _Period, 1);
    if((m_lastMainStructure.isCeiling && low < m_anchorPoint.price) || (!m_lastMainStructure.isCeiling && high > m_anchorPoint.price))
    {
        ResetAnalysis("لنگرگاه سوراخ شد.");
        return;
    }
    if(!m_activeFibo.isActive) return;
    double p0 = m_activeFibo.p0_price, p100 = m_activeFibo.p100_price;
    double zoneStart = p0 + (p100 - p0) * (InpEntryZone_Start / 100.0);
    double zoneEnd = p0 + (p100 - p0) * (InpEntryZone_End / 100.0);
    if(zoneStart > zoneEnd) { double temp = zoneStart; zoneStart = zoneEnd; zoneEnd = temp; }
    if(low <= zoneEnd && high >= zoneStart) m_state = STATE_IN_ENTRY_ZONE;
    else if(m_state == STATE_IN_ENTRY_ZONE) ResetAnalysis("قیمت از ناحیه ورود خارج شد.");
}

ENUM_FIBO_STATUS CFibonacciEngine::GetFiboStatus()
{
    switch(m_state)
    {
        case STATE_IN_ENTRY_ZONE: return STATUS_IN_ENTRY_ZONE;
        case STATE_FIBO_1_ACTIVE: case STATE_FIBO_2_ACTIVE: case STATE_AWAITING_TRIGGER_1: return STATUS_AWAITING_ENTRY;
        default: return STATUS_NO_FIBO;
    }
}

void CFibonacciEngine::ResetAnalysis(string reason)
{
    ClearAllGraphics(reason);
    m_activeFibo.isActive = false;
    m_state = STATE_SCOUTING;
}

void CFibonacciEngine::ClearAllGraphics(string reason)
{
    int total = ObjectsTotal(0, -1, -1);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if(StringFind(name, m_chartPrefix) == 0) ObjectDelete(0, name);
    }
    ChartRedraw();
}

void CFibonacciEngine::DrawStatusLabel()
{
    string statusText = "FiboEngine: ", objName = m_chartPrefix + "StatusLabel";
    color statusColor = clrWhite;
    switch(m_state)
    {
        case STATE_SCOUTING: statusText += "Scouting for BOS..."; break;
        case STATE_AWAITING_TRIGGER_1: statusText += "Awaiting Type 1 Trigger"; break;
        case STATE_FIBO_1_ACTIVE: statusText += "Floating Fibo Active"; break;
        case STATE_FIBO_2_ACTIVE: statusText += "Extension Fibo Active"; break;
        case STATE_IN_ENTRY_ZONE: statusText += "!!! PRICE IN ENTRY ZONE !!!"; statusColor = clrGold; break;
        case STATE_ANALYSIS_COMPLETE: statusText += "Analysis Complete."; break;
    }
    if(ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 15);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
        ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
    }
    ObjectSetString(0, objName, OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, statusColor);
}

void CFibonacciEngine::DrawFibonacci()
{
    if(!m_activeFibo.isActive) return;
    string objName = m_activeFibo.fiboName;
    if(ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_FIBO, 0, m_activeFibo.p0_time, m_activeFibo.p0_price, m_activeFibo.p100_time, m_activeFibo.p100_price);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrAqua);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
        string levels[];
        int count = StringSplit(InpFiboLevelsToShow, ',', levels);
        ObjectSetInteger(0, objName, OBJPROP_LEVELS, count);
        for(int i = 0; i < count; i++) ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, i, StringToDouble(levels[i]));
    }
    else
    {
        ObjectMove(0, objName, 0, m_activeFibo.p0_time, m_activeFibo.p0_price);
        ObjectMove(0, objName, 1, m_activeFibo.p100_time, m_activeFibo.p100_price);
    }
}

void CFibonacciEngine::DrawEntryZone()
{
    if(!m_activeFibo.isActive) return;
    string objName = m_chartPrefix + "EntryZone";
    double p0 = m_activeFibo.p0_price, p100 = m_activeFibo.p100_price;
    double level_start_price = p0 + (p100 - p0) * (InpEntryZone_Start / 100.0);
    double level_end_price = p0 + (p100 - p0) * (InpEntryZone_End / 100.0);
    datetime time1 = MathMax(m_activeFibo.p0_time, m_activeFibo.p100_time);
    datetime time2 = time1 + PeriodSeconds() * 200;
    
    if(ObjectFind(0, objName) < 0) ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 0, 0);
    
    ObjectSetInteger(0, objName, OBJPROP_TIME, 0, time1);
    ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, level_start_price);
    ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2);
    ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, level_end_price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, InpEntryZone_Color);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    ObjectSetInteger(0, objName, OBJPROP_FILL, true);
}

void CFibonacciEngine::DrawMainStructure()
{
    if(m_lastMainStructure.id == "") return;
    string starName = m_chartPrefix + "MainStar_" + m_lastMainStructure.id;
    string bosName = m_chartPrefix + "BOS_" + m_lastMainStructure.id;
    
    if(ObjectFind(0, starName) < 0) ObjectCreate(0, starName, OBJ_ARROW, 0, m_lastMainStructure.peakTime, m_lastMainStructure.peakPrice);
    ObjectSetInteger(0, starName, OBJPROP_ARROWCODE, 174);
    ObjectSetInteger(0, starName, OBJPROP_COLOR, clrDodgerBlue);
    ObjectSetInteger(0, starName, OBJPROP_WIDTH, 2);
    
    if(InpShowBOS)
    {
        if(ObjectFind(0, bosName) < 0) ObjectCreate(0, bosName, OBJ_TEXT, 0, m_lastMainStructure.breakTime, m_lastMainStructure.peakPrice);
        ObjectSetString(0, bosName, OBJPROP_TEXT, "BOS");
        ObjectSetInteger(0, bosName, OBJPROP_COLOR, clrOrange);
        ObjectSetInteger(0, bosName, OBJPROP_FONTSIZE, 12);
        ObjectSetInteger(0, bosName, OBJPROP_ANCHOR, m_lastMainStructure.isCeiling ? ANCHOR_BOTTOM : ANCHOR_TOP);
    }
}

void CFibonacciEngine::DrawAnchorBlock()
{
    if(m_anchorPoint.time == 0 || !InpShowAnchorBlock) return;
    string objName = m_chartPrefix + "AnchorBlock";
    
    if (m_anchorPoint.index < 0) return;
    
    double high = iHigh(_Symbol, _Period, m_anchorPoint.index);
    double low = iLow(_Symbol, _Period, m_anchorPoint.index);
    datetime time1 = iTime(_Symbol, _Period, m_anchorPoint.index);
    datetime time2 = time1 + PeriodSeconds();
    
    if(ObjectFind(0, objName) < 0) ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 0, 0);
    
    ObjectSetInteger(0, objName, OBJPROP_TIME, 0, time1);
    ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, low);
    ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2);
    ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, high);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, InpAnchorBlock_Color);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    ObjectSetInteger(0, objName, OBJPROP_FILL, false);
}

void CFibonacciEngine::RemovePeakValleyFromArray(string id, bool isCeiling)
{
    PeakValley &arr[] = isCeiling ? m_ceilings : m_valleys;
    int &total = isCeiling ? m_ceilings_total : m_valleys_total;
    int indexToRemove = -1;

    for(int i=0; i<total; i++)
    {
        if(arr[i].id == id)
        {
            indexToRemove = i;
            break;
        }
    }

    if(indexToRemove != -1)
    {
        for(int i = indexToRemove; i < total - 1; i++)
        {
            arr[i] = arr[i+1];
        }
        total--;
    }
}

bool CFibonacciEngine::IsNewStructureDominant(const PeakValley &structure, datetime breakTime)
{
    if(m_lastMainStructure.id == "") return true;

    if(InpMainPeakValleyMode == MODE_BREAK_TIME)
    {
        return (breakTime > m_lastMainStructure.breakTime);
    }
    else // MODE_PEAK_TIME
    {
        return (structure.time > m_lastMainStructure.peakTime);
    }
}

