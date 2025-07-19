//+------------------------------------------------------------------+
//|                                           FibonacciEngine.mqh |
//|        A Professional Fibonacci Structure & Analysis Library     |
//|                                     Copyright 2025, HipoAlgoritm |
//+------------------------------------------------------------------+
#property copyright "Mohammad Khajavi"
#property link      "https://HipoAlgoritm.com"
#property version   "1.00"
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

//--- وضعیت داخلی موتور
enum ENUM_FIBO_ENGINE_STATE
{
    STATE_SCOUTING,             // در حال نقشه‌برداری و انتظار برای شکست
    STATE_AWAITING_TRIGGER_1,   // منتظر تریگر نوع ۱ (عبور از سقف/کف مینور)
    STATE_FIBO_1_ACTIVE,        // فیبوی شناور (نوع ۱) فعال است
    STATE_FIBO_2_ACTIVE,        // فیبوی اکستنشن (نوع ۲) فعال است
    STATE_IN_ENTRY_ZONE,        // قیمت در ناحیه ورود قرار دارد
    STATE_ANALYSIS_COMPLETE     // تحلیل تمام شده و منتظر ریست است
};

//--- وضعیت گزارش به اکسپرت
enum ENUM_FIBO_STATUS
{
    STATUS_NO_FIBO,                 // هیچ فیبوی فعالی وجود ندارد
    STATUS_AWAITING_ENTRY,          // فیبو رسم شده و منتظر ورود به ناحیه است
    STATUS_IN_ENTRY_ZONE,           // قیمت در ناحیه ورود است (سیگنال مهم)
    STATUS_INVALIDATED_OVERRIDDEN,  // ستاپ باطل شد (ساختار جدیدتر پیدا شد)
    STATUS_INVALIDATED_ANCHOR_BROKEN, // ستاپ باطل شد (لنگرگاه سوراخ شد)
    STATUS_INVALIDATED_ZONE_PASSED  // ستاپ باطل شد (قیمت از ناحیه ورود عبور کرد)
};

//--- جهت درخواست تحلیل
enum ENUM_TRADE_DIRECTION
{
    DIRECTION_BUY,
    DIRECTION_SELL
};

//--- ساختار داده‌های پایه
struct PeakValley
{
    double   price;
    datetime time;
    int      index;
};

//--- ساختار داده‌های ساختار اصلی
struct MainPeakValley
{
    double   peakPrice;
    datetime peakTime;
    datetime breakTime;
    string   id;
    bool     isCeiling;
};

//--- ساختار داده‌های فیبوناچی فعال
struct ActiveFiboInfo
{
    bool     isActive;
    string   fiboName;
    double   p0_price;   // قیمت نقطه صفر
    datetime p0_time;    // زمان نقطه صفر
    double   p100_price; // قیمت نقطه صد
    datetime p100_time;  // زمان نقطه صد
};

//+------------------------------------------------------------------+
//|                                                                  |
//|                  کلاس اصلی موتور فیبوناچی (CFibonacciEngine)        |
//|                                                                  |
//+------------------------------------------------------------------+
class CFibonacciEngine
{
private:
    // --- وضعیت و شناسایی ---
    ENUM_FIBO_ENGINE_STATE m_state;
    long                   m_magicNumber;
    string                 m_chartPrefix;

    // --- هندل و آرایه‌ها ---
    int                    m_handleFineflow;
    PeakValley             m_ceilings[50]; // نگهداری ۵۰ سقف آخر
    PeakValley             m_valleys[50];  // نگهداری ۵۰ کف آخر
    int                    m_ceilings_total;
    int                    m_valleys_total;

    // --- داده‌های ساختار اصلی و فعال ---
    MainPeakValley         m_lastMainStructure;
    PeakValley             m_anchorPoint;
    ActiveFiboInfo         m_activeFibo;
    ENUM_FIBO_STRATEGY_MODE m_active_fibo_type;

    // --- متغیرهای کمکی ---
    datetime               m_lastCandleTime;

    // --- توابع داخلی (منطق اصلی) ---
    void                   ScoutForStructure();
    void                   ManageDataArrays(const PeakValley &newPeak, bool isCeiling);
    bool                   DetectBreak(const MainPeakValley &structure, double &breakPrice, datetime &breakTime);
    void                   IdentifyAnchorPoint();
    void                   RunTheGate(ENUM_TRADE_DIRECTION direction);
    void                   ActivateFiboType1();
    void                   ActivateFiboType2();
    void                   UpdateFiboType1();
    void                   CheckConditions();
    void                   ResetAnalysis();

    // --- توابع گرافیکی ---
    void                   DrawStatusLabel();
    void                   DrawMainStructure();
    void                   DrawAnchorBlock();
    void                   DrawFibonacci();
    void                   DrawEntryZone();
    void                   ClearAllGraphics(string reason);

public:
    // --- توابع عمومی (رابط کاربری کتابخانه) ---
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

// --- تابع سازنده ---
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
}

// --- تابع مخرب ---
void CFibonacciEngine::~CFibonacciEngine()
{
    // Deinit() should be called manually
}

// --- تابع راه‌اندازی ---
bool CFibonacciEngine::Init(long expert_magic_number)
{
    m_magicNumber = expert_magic_number;
    m_chartPrefix = "FiboEngine_" + (string)m_magicNumber + "_" + (string)ChartID() + "_";

    m_handleFineflow = iCustom(_Symbol, _Period, "fineflow",
                               InpFineflow_EnforceStrictSequence,
                               InpFineflow_DetectionMethod,
                               InpFineflow_Lookback,
                               // ... Pass other fineflow parameters here if needed
                               InpFineflow_AtrPeriod,
                               InpFineflow_AtrMultiplier
                              );

    if(m_handleFineflow == INVALID_HANDLE)
    {
        Print("خطا: کتابخانه فیبوناچی نتوانست اندیکاتور fineflow را لود کند!");
        return false;
    }

    Print("موتور فیبوناچی با موفقیت راه‌اندازی شد.");
    return true;
}

// --- تابع پاکسازی ---
void CFibonacciEngine::Deinit()
{
    if(m_handleFineflow != INVALID_HANDLE)
        IndicatorRelease(m_handleFineflow);

    ClearAllGraphics("Deinitialization");
    Print("موتور فیبوناچی با موفقیت غیرفعال شد.");
}

// --- نبض اصلی کتابخانه ---
void CFibonacciEngine::OnTick()
{
    // --- اجرای منطق فقط در کندل جدید برای بهینه‌سازی ---
    datetime currentTime = iTime(_Symbol, _Period, 0);
    if(currentTime == m_lastCandleTime)
        return;
    m_lastCandleTime = currentTime;

    // --- قانون بازنشستگی: اگر ساختار جدیدی پیدا شد، تحلیل قبلی باطل است ---
    // (این منطق در ScoutForStructure پیاده‌سازی می‌شود)

    // --- ماشین حالت ---
    switch(m_state)
    {
        case STATE_SCOUTING:
            ScoutForStructure();
            break;

        case STATE_AWAITING_TRIGGER_1:
            // Check if trigger condition is met
            // if yes, m_state = STATE_FIBO_1_ACTIVE; DrawFibonacci();
            // if anchor broken, ResetAnalysis();
            break;

        case STATE_FIBO_1_ACTIVE:
            UpdateFiboType1(); // آپدیت فیبوی شناور
            CheckConditions(); // چک کردن شرایط ورود یا ابطال
            break;

        case STATE_FIBO_2_ACTIVE:
            // Update Fibo Type 2 logic (check for extension touch)
            CheckConditions();
            break;
            
        case STATE_IN_ENTRY_ZONE:
            CheckConditions(); // چک کردن خروج از ناحیه یا ابطال
            break;
    }

    if(InpShowStatusLabel)
        DrawStatusLabel();
}

// --- تابع اصلی نقشه‌برداری ---
void CFibonacciEngine::ScoutForStructure()
{
    // 1. Get new peaks and valleys from Fineflow
    // ... (Code to call iCustom and get data)

    // 2. Manage arrays to keep last 50
    // ...

    // 3. Check for Break of Structure (BOS) for the last known peaks/valleys
    // ...

    // 4. If a new BOS is detected:
    //    - Check override rule: If m_activeFibo.isActive, call ResetAnalysis().
    //    - Update m_lastMainStructure with the new broken structure info.
    //    - Call IdentifyAnchorPoint().
    //    - Call DrawMainStructure() and DrawAnchorBlock().
}

// --- تابع شناسایی لنگرگاه ---
void CFibonacciEngine::IdentifyAnchorPoint()
{
    // Scan between m_lastMainStructure.peakTime and m_lastMainStructure.breakTime
    // Find the lowest low (for bullish BOS) or highest high (for bearish BOS)
    // Store the result in m_anchorPoint
}

// --- تابع تحلیل و رسم درخواستی ---
bool CFibonacciEngine::AnalyzeAndDrawFibo(ENUM_TRADE_DIRECTION direction)
{
    if(m_lastMainStructure.id == "")
    {
        Print("تحلیل فیبوناچی ممکن نیست: هیچ ساختار اصلی شکسته شده‌ای یافت نشد.");
        return false;
    }

    // --- قانون هماهنگی جهت ---
    if(direction == DIRECTION_BUY && !m_lastMainStructure.isCeiling)
    {
        Print("تحلیل خرید رد شد: آخرین ساختار شکسته شده، یک کف (نزولی) است.");
        return false;
    }
    if(direction == DIRECTION_SELL && m_lastMainStructure.isCeiling)
    {
        Print("تحلیل فروش رد شد: آخرین ساختار شکسته شده، یک سقف (صعودی) است.");
        return false;
    }

    // --- اجرای دروازه تشخیص نوع ---
    RunTheGate(direction);
    return true;
}

// --- تابع دروازه تشخیص نوع ---
void CFibonacciEngine::RunTheGate(ENUM_TRADE_DIRECTION direction)
{
    // This is a complex logic part
    // 1. Scan for a minor corrective peak/valley between anchor and break point.
    // 2. If found, virtually draw a fibo and check if price retraced to 50-61.8 zone.
    
    bool isType1ConditionMet = false; // Placeholder for the actual logic
    
    if(isType1ConditionMet && (InpStrategyMode == MODE_BOTH || InpStrategyMode == MODE_FLOATING_ONLY))
    {
        m_active_fibo_type = MODE_FLOATING_ONLY;
        m_state = STATE_AWAITING_TRIGGER_1;
        Print("ستاپ نوع ۱ شناسایی شد. منتظر تریگر...");
    }
    else if(InpStrategyMode == MODE_BOTH || InpStrategyMode == MODE_EXTENSION_ONLY)
    {
        m_active_fibo_type = MODE_EXTENSION_ONLY;
        ActivateFiboType2();
        Print("ستاپ نوع ۲ شناسایی و فعال شد.");
    }
}

// --- فعال‌سازی و آپدیت فیبوی نوع ۲ ---
void CFibonacciEngine::ActivateFiboType2()
{
    m_activeFibo.isActive = true;
    m_activeFibo.fiboName = m_chartPrefix + "Fibo_Ext_" + m_lastMainStructure.id;
    m_activeFibo.p0_price = m_anchorPoint.price;
    m_activeFibo.p0_time = m_anchorPoint.time;
    m_activeFibo.p100_price = m_lastMainStructure.peakPrice;
    m_activeFibo.p100_time = m_lastMainStructure.peakTime;
    
    m_state = STATE_FIBO_2_ACTIVE;
    DrawFibonacci();
    DrawEntryZone(); // The entry zone for type 2 would be based on the extension level
}


// --- آپدیت فیبوی شناور ---
void CFibonacciEngine::UpdateFiboType1()
{
    // Update m_activeFibo.p100_price to the current high/low
    // Redraw the fibonacci
    DrawFibonacci();
    DrawEntryZone();
}

// --- چک کردن شرایط ورود و ابطال ---
void CFibonacciEngine::CheckConditions()
{
    if(!m_activeFibo.isActive) return;

    double high = iHigh(_Symbol, _Period, 1);
    double low = iLow(_Symbol, _Period, 1);
    
    // --- منطق چسبنده ناحیه ورود ---
    double zoneStart = MathMin(m_activeFibo.p0_price, m_activeFibo.p100_price) + MathAbs(m_activeFibo.p100_price - m_activeFibo.p0_price) * (InpEntryZone_Start/100.0);
    double zoneEnd = MathMin(m_activeFibo.p0_price, m_activeFibo.p100_price) + MathAbs(m_activeFibo.p100_price - m_activeFibo.p0_price) * (InpEntryZone_End/100.0);

    if(low <= zoneEnd && high >= zoneStart)
    {
        m_state = STATE_IN_ENTRY_ZONE;
    }
    else if (m_state == STATE_IN_ENTRY_ZONE) // Price was in the zone but now has left
    {
        m_state = STATE_ANALYSIS_COMPLETE;
        ResetAnalysis();
        Print("تحلیل باطل شد: قیمت از ناحیه ورود خارج شد.");
    }
    
    // --- چک کردن سوراخ شدن لنگرگاه ---
    // ...
}


// --- تابع گزارش وضعیت ---
ENUM_FIBO_STATUS CFibonacciEngine::GetFiboStatus()
{
    switch(m_state)
    {
        case STATE_IN_ENTRY_ZONE:        return STATUS_IN_ENTRY_ZONE;
        case STATE_FIBO_1_ACTIVE:
        case STATE_FIBO_2_ACTIVE:
        case STATE_AWAITING_TRIGGER_1:   return STATUS_AWAITING_ENTRY;
        default:                         return STATUS_NO_FIBO;
    }
}

// --- تابع ریست کردن تحلیل ---
void CFibonacciEngine::ResetAnalysis()
{
    ClearAllGraphics("Resetting Analysis");
    m_activeFibo.isActive = false;
    m_state = STATE_SCOUTING;
}


// --- تابع پاکسازی گرافیک ---
void CFibonacciEngine::ClearAllGraphics(string reason)
{
    ObjectsDeleteAll(0, m_chartPrefix);
    Print("اشیاء گرافیکی موتور فیبوناچی پاکسازی شدند. دلیل: " + reason);
}

// --- تابع رسم لیبل وضعیت ---
void CFibonacciEngine::DrawStatusLabel()
{
    string statusText = "وضعیت موتور فیبوناچی: ";
    switch(m_state)
    {
        case STATE_SCOUTING:             statusText += "در حال نقشه‌برداری..."; break;
        case STATE_AWAITING_TRIGGER_1:   statusText += "منتظر تریگر نوع ۱"; break;
        case STATE_FIBO_1_ACTIVE:        statusText += "فیبوی شناور فعال"; break;
        case STATE_FIBO_2_ACTIVE:        statusText += "فیبوی اکستنشن فعال"; break;
        case STATE_IN_ENTRY_ZONE:        statusText += "!!! قیمت در ناحیه ورود !!!"; break;
        case STATE_ANALYSIS_COMPLETE:    statusText += "تحلیل تمام شد."; break;
    }
    
    string objName = m_chartPrefix + "StatusLabel";
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
    ObjectSetInteger(0, objName, OBJPROP_COLOR, (m_state == STATE_IN_ENTRY_ZONE) ? clrGold : clrWhite);
}

// --- تابع رسم فیبوناچی ---
void CFibonacciEngine::DrawFibonacci()
{
    if(!m_activeFibo.isActive) return;
    
    string objName = m_activeFibo.fiboName;
    
    if(ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_FIBO, 0, m_activeFibo.p0_time, m_activeFibo.p0_price, m_activeFibo.p100_time, m_activeFibo.p100_price);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrAqua);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
        
        // Parse the levels string and add them
        string levels[];
        int count = StringSplit(InpFiboLevelsToShow, ',', levels);
        ObjectSetInteger(0, objName, OBJPROP_LEVELS, count);
        for(int i=0; i<count; i++)
        {
            ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, i, StringToDouble(levels[i]));
        }
    }
    else
    {
        ObjectMove(0, objName, 0, m_activeFibo.p0_time, m_activeFibo.p0_price);
        ObjectMove(0, objName, 1, m_activeFibo.p100_time, m_activeFibo.p100_price);
    }
}

// --- تابع رسم ناحیه ورود ---
void CFibonacciEngine::DrawEntryZone()
{
    if(!m_activeFibo.isActive) return;

    string objName = m_chartPrefix + "EntryZone";
    
    double level_start_price = m_activeFibo.p0_price + (m_activeFibo.p100_price - m_activeFibo.p0_price) * (InpEntryZone_Start / 100.0);
    double level_end_price = m_activeFibo.p0_price + (m_activeFibo.p100_price - m_activeFibo.p0_price) * (InpEntryZone_End / 100.0);
    
    datetime time1 = m_activeFibo.p100_time;
    datetime time2 = time1 + PeriodSeconds() * 100; // Extend to the future

    if(ObjectFind(0, objName) < 0)
    {
        ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time1, level_start_price, time2, level_end_price);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, InpEntryZone_Color);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
        ObjectSetBool(0, objName, OBJPROP_BACK, true);
        ObjectSetBool(0, objName, OBJPROP_FILL, true);
    }
    else
    {
        ObjectMove(0, objName, 0, time1, level_start_price);
        ObjectMove(0, objName, 1, time2, level_end_price);
    }
}

// --- سایر توابع رسم (BOS, Anchor Block, ...) در اینجا پیاده‌سازی می‌شوند ---
// ...


