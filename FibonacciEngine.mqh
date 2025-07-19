
//+------------------------------------------------------------------+
//| FibonacciEngine.mqh                                              |
//| کتابخانه‌ای برای رسم فیبوناچی‌های نوع اول (شناور) و نوع دوم (اکستنشن) |
//| شناسایی سقف‌ها، کف‌ها، شکست‌ها و نقاط ورود با اندیکاتور Fineflow  |
//| کاملاً مستقل، با لاگ بهینه، آپدیت فیبوناچی و نمایش وضعیت در چارت |
//| نسخه: 1.02                                                      |
//| تاریخ: 2025-07-19                                              |
//+------------------------------------------------------------------+

#property copyright "Your Name"
#property version   "1.02"
#property strict

//--- شامل فایل‌های مورد نیاز
#include <Trade\Trade.mqh>

//--- تعریف ثابت‌های لازم از Fineflow
enum E_DetectionMethod {
   METHOD_SIMPLE,         // روش ساده (فراکتال)
   METHOD_SEQUENTIAL,     // روش پلکانی انعطاف‌پذیر
   METHOD_POWER_SWING,    // روش فیلتر قدرت
   METHOD_ZIGZAG,         // روش زیگزاگ
   METHOD_BREAK_OF_STRUCTURE, // روش شکست ساختار (BOS)
   METHOD_MARKET_STRUCTURE_SHIFT // روش تغییر ساختار بازار (MSS)
};

enum E_SequentialCriterion {
   CRITERION_HIGH,     // استفاده از High برای پلکانی
   CRITERION_LOW,      // استفاده از Low برای پلکانی
   CRITERION_OPEN,     // استفاده از Open برای پلکانی
   CRITERION_CLOSE     // استفاده از Close برای پلکانی
};

//--- ورودی‌ها (Inputs)
input group "تنظیمات عمومی"
input bool EnforceStrictSequence = true; // اعمال توالی اجباری سقف/کف
input ENUM_TIMEFRAMES TF = PERIOD_M5; // تایم‌فریم اندیکاتور Fineflow
input int Lookback = 3; // تعداد کندل‌ها برای نگاه به عقب و جلو
input int MaxScanDepth = 200; // حداکثر کندل‌ها برای اسکن
input int MaxArraySize = 50; // حداکثر اندازه آرایه‌های سقف و کف
input bool EnableLogging = true; // فعال‌سازی لاگ‌ها
input E_DetectionMethod DetectionMethod = METHOD_POWER_SWING; // روش تشخیص Fineflow
input int SequentialLookback = 2; // تعداد کندل‌ها برای روش پلکانی
input bool UseStrictSequential = true; // حالت سخت‌گیرانه پلکانی
input E_SequentialCriterion SequentialCriterion = CRITERION_HIGH; // معیار پلکانی
input int AtrPeriod = 14; // دوره ATR
input double AtrMultiplier = 2.5; // ضریب ATR
input int ZigZagDepth = 12; // عمق زیگزاگ
input double ZigZagDeviation = 5; // انحراف زیگزاگ

input group "تنظیمات شکست"
enum ENUM_BREAK_TYPE {
   BREAK_SIMPLE,      // شکست ساده
   BREAK_CONFIRMED    // شکست تأیید شده
};
input ENUM_BREAK_TYPE BreakType = BREAK_CONFIRMED; // نوع شکست
input int ConfirmationCandles = 5; // تعداد کندل‌های تأیید برای شکست

input group "تنظیمات استراتژی فیبوناچی"
input bool EnableFiboType1 = true; // فعال‌سازی فیبوناچی نوع اول (شناور)
input bool EnableFiboType2 = true; // فعال‌سازی فیبوناچی نوع دوم (اکستنشن)
input double FiboEntryZoneMin = 50.0; // حداقل درصد ناحیه ورود (50%)
input double FiboEntryZoneMax = 68.0; // حداکثر درصد ناحیه ورود (68%)

input group "تنظیمات گرافیکی"
input color PeakColor = clrRed; // رنگ علامت سقف (ستاره)
input color ValleyColor = clrGreen; // رنگ علامت کف (ستاره)
input color BOSColor = clrBlue; // رنگ نوشته BOS
input color AnchorBlockColor = clrYellow; // رنگ مستطیل اوردر بلاک میانی
input color EntryZoneColor = clrLimeGreen; // رنگ ناحیه ورود
input int FontSize = 10; // اندازه فونت نوشته BOS و وضعیت
input string FontName = "Arial"; // نام فونت

//--- تعریف enums برای مدیریت وضعیت
enum ENUM_FIBO_STATUS {
   STATUS_WAITING,           // در انتظار ساختار جدید
   STATUS_FIBO_TYPE1_ACTIVE, // فیبوناچی نوع اول فعال
   STATUS_FIBO_TYPE2_ACTIVE, // فیبوناچی نوع دوم فعال
   STATUS_IN_ENTRY_ZONE,     // در ناحیه ورود
   STATUS_INVALID            // تحلیل باطل شده
};

//--- ساختار برای ذخیره اطلاعات سقف و کف
struct PeakValley {
   double price;   // قیمت سقف یا کف
   datetime time;  // زمان سقف یا کف
   string id;      // شناسه منحصربه‌فرد
   datetime breakTime; // زمان شکست
};

//--- ساختار برای ذخیره اطلاعات فیبوناچی
struct FiboStructure {
   double zeroLevel;    // سطح صفر فیبوناچی
   double hundredLevel; // سطح 100 فیبوناچی
   datetime zeroTime;   // زمان سطح صفر
   datetime hundredTime;// زمان سطح 100
   bool isType1;        // نوع فیبوناچی (نوع 1 یا 2)
   bool isBullish;      // جهت (صعودی یا نزولی)
   string fiboId;       // شناسه فیبوناچی
};

//--- کلاس اصلی کتابخانه
class CFibonacciEngine {
private:
   //--- متغیرهای داخلی
   int handleFineflow;          // هندل اندیکاتور Fineflow
   PeakValley m_ceilings[];     // آرایه سقف‌ها
   PeakValley m_valleys[];      // آرایه کف‌ها
   FiboStructure currentFibo;   // فیبوناچی فعلی
   ENUM_FIBO_STATUS currentStatus; // وضعیت فعلی کتابخانه
   datetime lastCandleTime;     // زمان آخرین کندل پردازش‌شده
   string statusLabelName;      // نام لیبل وضعیت

   //--- توابع کمکی
   bool IsNewCandle();
   void ManageDataArrays();
   void DrawGraphics(string type, double price, datetime time, string id, bool isCeiling = true);
   void DrawStatusLabel();
   void ClearOldGraphics();
   bool FindMinorCorrection(datetime startTime, datetime endTime, bool isBullish, double &minorPrice, datetime &minorTime);
   bool CheckEntryZone(double zeroLevel, double hundredLevel, double minPercent, double maxPercent);
   void ResetAnalysis();
   void UpdateFiboType1();
   void UpdateFiboType2();

public:
   //--- سازنده و دفع‌کننده
   CFibonacciEngine();
   ~CFibonacciEngine();

   //--- توابع اصلی
   bool Init();
   void ScoutForStructure();
   bool AnalyzeAndDrawFibo(bool isBuy);
   ENUM_FIBO_STATUS GetFiboStatus();
   void CheckConditions();
};

//+------------------------------------------------------------------+
//| سازنده کلاس                                                    |
//+------------------------------------------------------------------+
CFibonacciEngine::CFibonacciEngine()
{
   handleFineflow = INVALID_HANDLE;
   ArraySetAsSeries(m_ceilings, true);
   ArraySetAsSeries(m_valleys, true);
   currentStatus = STATUS_WAITING;
   lastCandleTime = 0;
   statusLabelName = "FiboEngine_Status";
   currentFibo.zeroLevel = 0;
   currentFibo.hundredLevel = 0;
   currentFibo.zeroTime = 0;
   currentFibo.hundredTime = 0;
   currentFibo.isType1 = false;
   currentFibo.isBullish = true;
   currentFibo.fiboId = "";
}

//+------------------------------------------------------------------+
//| دفع‌کننده کلاس                                                 |
//+------------------------------------------------------------------+
CFibonacciEngine::~CFibonacciEngine()
{
   if(handleFineflow != INVALID_HANDLE)
      IndicatorRelease(handleFineflow);
   ObjectsDeleteAll(0, -1, -1);
}

//+------------------------------------------------------------------+
//| تابع مقداردهی اولیه                                            |
//+------------------------------------------------------------------+
bool CFibonacciEngine::Init()
{
   //--- بارگذاری اندیکاتور Fineflow
   handleFineflow = iCustom(_Symbol, TF, "Fineflow",
                           EnforceStrictSequence,
                           DetectionMethod,
                           Lookback,
                           SequentialLookback,
                           UseStrictSequential,
                           SequentialCriterion,
                           AtrPeriod,
                           AtrMultiplier,
                           ZigZagDepth,
                           ZigZagDeviation,
                           false); // EnableLogging
   if(handleFineflow == INVALID_HANDLE)
   {
      if(EnableLogging) Print("خطا در بارگذاری اندیکاتور Fineflow");
      return false;
   }

   //--- ایجاد لیبل وضعیت
   if(!ObjectCreate(0, statusLabelName, OBJ_LABEL, 0, 0, 0))
   {
      if(EnableLogging) Print("خطا در ایجاد لیبل وضعیت");
      return false;
   }
   ObjectSetInteger(0, statusLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, statusLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, statusLabelName, OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(0, statusLabelName, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, statusLabelName, OBJPROP_FONT, FontName);
   ObjectSetInteger(0, statusLabelName, OBJPROP_COLOR, clrWhite);

   return true;
}

//+------------------------------------------------------------------+
//| بررسی کندل جدید                                                |
//+------------------------------------------------------------------+
bool CFibonacciEngine::IsNewCandle()
{
   datetime currentTime = iTime(_Symbol, _Period, 0);
   if(currentTime != lastCandleTime)
   {
      lastCandleTime = currentTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| مدیریت آرایه‌های داده                                          |
//+------------------------------------------------------------------+
void CFibonacciEngine::ManageDataArrays()
{
   if(ArraySize(m_ceilings) > MaxArraySize)
   {
      ArrayRemove(m_ceilings, 0, ArraySize(m_ceilings) - MaxArraySize);
      if(EnableLogging) Print("مدیریت حافظه: کاهش اندازه آرایه سقف‌ها به ", MaxArraySize);
   }
   if(ArraySize(m_valleys) > MaxArraySize)
   {
      ArrayRemove(m_valleys, 0, ArraySize(m_valleys) - MaxArraySize);
      if(EnableLogging) Print("مدیریت حافظه: کاهش اندازه آرایه کف‌ها به ", MaxArraySize);
   }
}

//+------------------------------------------------------------------+
//| نقشه‌بردار برای شناسایی ساختارها                              |
//+------------------------------------------------------------------+
void CFibonacciEngine::ScoutForStructure()
{
   if(!IsNewCandle()) return;

   //--- جمع‌آوری سقف‌ها و کف‌ها
   double highBuffer[1];
   double lowBuffer[1];
   datetime times[1];
   int start = 1;
   int end = MathMin(MaxScanDepth, iBars(_Symbol, TF) - 1);

   for(int i = start; i <= end; i++)
   {
      if(CopyBuffer(handleFineflow, 0, i, 1, highBuffer) > 0 &&
         CopyBuffer(handleFineflow, 1, i, 1, lowBuffer) > 0 &&
         CopyTime(_Symbol, TF, i, 1, times) > 0)
      {
         if(highBuffer[0] != EMPTY_VALUE && highBuffer[0] > 0)
         {
            int size = ArraySize(m_ceilings);
            ArrayResize(m_ceilings, size + 1);
            m_ceilings[size].price = highBuffer[0];
            m_ceilings[size].time = times[0];
            m_ceilings[size].id = "C_" + TimeToString(times[0]);
            m_ceilings[size].breakTime = 0;
            if(EnableLogging) Print("سقف جدید: ", m_ceilings[size].id, " قیمت: ", highBuffer[0], " زمان: ", TimeToString(times[0]));
         }
         if(lowBuffer[0] != EMPTY_VALUE && lowBuffer[0] > 0)
         {
            int size = ArraySize(m_valleys);
            ArrayResize(m_valleys, size + 1);
            m_valleys[size].price = lowBuffer[0];
            m_valleys[size].time = times[0];
            m_valleys[size].id = "V_" + TimeToString(times[0]);
            m_valleys[size].breakTime = 0;
            if(EnableLogging) Print("کف جدید: ", m_valleys[size].id, " قیمت: ", lowBuffer[0], " زمان: ", TimeToString(times[0]));
         }
      }
   }

   //--- مدیریت حافظه
   ManageDataArrays();

   //--- تشخیص شکست‌ها
   double highPrice = iHigh(_Symbol, _Period, 1);
   double lowPrice = iLow(_Symbol, _Period, 1);
   datetime currentTime = iTime(_Symbol, _Period, 1);
   bool newBreakFound = false;
   PeakValley dominantStructure = {0, 0, "", 0};

   if(BreakType == BREAK_SIMPLE)
   {
      for(int i = 0; i < ArraySize(m_ceilings); i++)
      {
         if(m_ceilings[i].breakTime == 0 && highPrice > m_ceilings[i].price)
         {
            m_ceilings[i].breakTime = currentTime;
            if(EnableLogging) Print("شکست سقف: ", m_ceilings[i].id, " در زمان ", TimeToString(currentTime));
            if(dominantStructure.breakTime == 0 || m_ceilings[i].breakTime > dominantStructure.breakTime)
            {
               dominantStructure = m_ceilings[i];
               newBreakFound = true;
            }
         }
      }
      for(int i = 0; i < ArraySize(m_valleys); i++)
      {
         if(m_valleys[i].breakTime == 0 && lowPrice < m_valleys[i].price)
         {
            m_valleys[i].breakTime = currentTime;
            if(EnableLogging) Print("شکست کف: ", m_valleys[i].id, " در زمان ", TimeToString(currentTime));
            if(dominantStructure.breakTime == 0 || m_valleys[i].breakTime > dominantStructure.breakTime)
            {
               dominantStructure = m_valleys[i];
               newBreakFound = true;
            }
         }
      }
   }
   else // BREAK_CONFIRMED
   {
      static PeakValley pendingBreaks[];
      ArraySetAsSeries(pendingBreaks, true);
      for(int i = 0; i < ArraySize(m_ceilings); i++)
      {
         if(m_ceilings[i].breakTime == 0 && highPrice > m_ceilings[i].price)
         {
            int size = ArraySize(pendingBreaks);
            ArrayResize(pendingBreaks, size + 1);
            pendingBreaks[size] = m_ceilings[i];
            pendingBreaks[size].breakTime = currentTime + ConfirmationCandles * PeriodSeconds(TF);
            if(EnableLogging) Print("شکست در انتظار تأیید سقف: ", m_ceilings[i].id);
         }
      }
      for(int i = 0; i < ArraySize(m_valleys); i++)
      {
         if(m_valleys[i].breakTime == 0 && lowPrice < m_valleys[i].price)
         {
            int size = ArraySize(pendingBreaks);
            ArrayResize(pendingBreaks, size + 1);
            pendingBreaks[size] = m_valleys[i];
            pendingBreaks[size].breakTime = currentTime + ConfirmationCandles * PeriodSeconds(TF);
            if(EnableLogging) Print("شکست در انتظار تأیید کف: ", m_valleys[i].id);
         }
      }
      for(int i = 0; i < ArraySize(pendingBreaks); i++)
      {
         if(pendingBreaks[i].breakTime > 0 && currentTime >= pendingBreaks[i].breakTime)
         {
            if(pendingBreaks[i].price > m_valleys[0].price) // سقف
            {
               for(int j = 0; j < ArraySize(m_ceilings); j++)
               {
                  if(m_ceilings[j].id == pendingBreaks[i].id)
                  {
                     m_ceilings[j].breakTime = currentTime;
                     if(EnableLogging) Print("شکست تأیید شده سقف: ", m_ceilings[j].id);
                     if(dominantStructure.breakTime == 0 || m_ceilings[j].breakTime > dominantStructure.breakTime)
                     {
                        dominantStructure = m_ceilings[j];
                        newBreakFound = true;
                     }
                     break;
                  }
               }
            }
            else // کف
            {
               for(int j = 0; j < ArraySize(m_valleys); j++)
               {
                  if(m_valleys[j].id == pendingBreaks[i].id)
                  {
                     m_valleys[j].breakTime = currentTime;
                     if(EnableLogging) Print("شکست تأیید شده کف: ", m_valleys[j].id);
                     if(dominantStructure.breakTime == 0 || m_valleys[j].breakTime > dominantStructure.breakTime)
                     {
                        dominantStructure = m_valleys[j];
                        newBreakFound = true;
                     }
                     break;
                  }
               }
            }
         }
      }
   }

   //--- علامت‌گذاری ساختار غالب
   if(newBreakFound)
   {
      ResetAnalysis();
      bool isCeiling = dominantStructure.price > m_valleys[0].price;
      DrawGraphics("structure", dominantStructure.price, dominantStructure.time, dominantStructure.id, isCeiling);
      DrawGraphics("bos", dominantStructure.price + (isCeiling ? _Point * 10 : -_Point * 10), dominantStructure.breakTime, dominantStructure.id + "_BOS", isCeiling);

      //--- پیدا کردن اوردر بلاک میانی (لنگرگاه)
      double anchorPrice = 0;
      datetime anchorTime = 0;
      int startShift = iBarShift(_Symbol, TF, dominantStructure.breakTime);
      int endShift = iBarShift(_Symbol, TF, dominantStructure.time);
      for(int i = startShift; i <= endShift; i++)
      {
         double currentPrice = isCeiling ? iLow(_Symbol, TF, i) : iHigh(_Symbol, TF, i);
         if(anchorPrice == 0 || (isCeiling && currentPrice < anchorPrice) || (!isCeiling && currentPrice > anchorPrice))
         {
            anchorPrice = currentPrice;
            anchorTime = iTime(_Symbol, TF, i);
         }
      }
      if(anchorPrice > 0)
      {
         DrawGraphics("anchor", anchorPrice, anchorTime, dominantStructure.id + "_Anchor", isCeiling);
         currentStatus = STATUS_WAITING;
         DrawStatusLabel();
      }
   }
}

//+------------------------------------------------------------------+
//| تحلیل و رسم فیبوناچی                                          |
//+------------------------------------------------------------------+
bool CFibonacciEngine::AnalyzeAndDrawFibo(bool isBuy)
{
   if(ArraySize(m_ceilings) == 0 || ArraySize(m_valleys) == 0) return false;

   //--- پیدا کردن آخرین ساختار شکسته
   PeakValley dominantStructure = {0, 0, "", 0};
   for(int i = 0; i < ArraySize(m_ceilings); i++)
   {
      if(m_ceilings[i].breakTime > 0 && (dominantStructure.breakTime == 0 || m_ceilings[i].breakTime > dominantStructure.breakTime))
         dominantStructure = m_ceilings[i];
   }
   for(int i = 0; i < ArraySize(m_valleys); i++)
   {
      if(m_valleys[i].breakTime > 0 && (dominantStructure.breakTime == 0 || m_valleys[i].breakTime > dominantStructure.breakTime))
         dominantStructure = m_valleys[i];
   }
   if(dominantStructure.breakTime == 0) return false;

   bool isCeiling = dominantStructure.price > m_valleys[0].price;
   if((isBuy && !isCeiling) || (!isBuy && isCeiling))
   {
      if(EnableLogging) Print("جهت درخواست با ساختار بازار هماهنگ نیست");
      return false;
   }

   //--- پیدا کردن اوردر بلاک میانی (لنگرگاه)
   double anchorPrice = 0;
   datetime anchorTime = 0;
   int startShift = iBarShift(_Symbol, TF, dominantStructure.breakTime);
   int endShift = iBarShift(_Symbol, TF, dominantStructure.time);
   for(int i = startShift; i <= endShift; i++)
   {
      double currentPrice = isCeiling ? iLow(_Symbol, TF, i) : iHigh(_Symbol, TF, i);
      if(anchorPrice == 0 || (isCeiling && currentPrice < anchorPrice) || (!isCeiling && currentPrice > anchorPrice))
      {
         anchorPrice = currentPrice;
         anchorTime = iTime(_Symbol, TF, i);
      }
   }
   if(anchorPrice == 0) return false;

   //--- فیبوناچی نوع دوم
   if(EnableFiboType2)
   {
      double fiboZero = anchorPrice;
      double fiboHundred = dominantStructure.price;
      string fiboId = "Fibo_Type2_" + TimeToString(dominantStructure.breakTime);
      
      //--- حذف فیبوناچی قبلی
      if(currentFibo.fiboId != "") ObjectDelete(0, currentFibo.fiboId);
      if(currentFibo.fiboId != "") ObjectDelete(0, currentFibo.fiboId + "_EntryZone");

      if(ObjectCreate(0, fiboId, OBJ_FIBO, 0, anchorTime, fiboZero, dominantStructure.time, fiboHundred))
      {
         ObjectSetInteger(0, fiboId, OBJPROP_LEVELS, 6);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 0, 0.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 1, 1.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 2, FiboEntryZoneMin / 100.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 3, FiboEntryZoneMax / 100.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 4, 1.5); // سطح 150%
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 5, 2.0); // سطح 200%
         ObjectSetInteger(0, fiboId, OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(0, fiboId, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, fiboId, OBJPROP_WIDTH, 1);

         //--- رسم ناحیه ورود
         double entryZoneMin = fiboZero + (fiboHundred - fiboZero) * (FiboEntryZoneMin / 100.0);
         double entryZoneMax = fiboZero + (fiboHundred - fiboZero) * (FiboEntryZoneMax / 100.0);
         string entryZoneId = fiboId + "_EntryZone";
         ObjectCreate(0, entryZoneId, OBJ_RECTANGLE, 0, anchorTime, entryZoneMin, dominantStructure.time, entryZoneMax);
         ObjectSetInteger(0, entryZoneId, OBJPROP_COLOR, EntryZoneColor);
         ObjectSetInteger(0, entryZoneId, OBJPROP_BACK, true);
         ObjectSetInteger(0, entryZoneId, OBJPROP_FILL, true);

         currentFibo.zeroLevel = fiboZero;
         currentFibo.hundredLevel = fiboHundred;
         currentFibo.zeroTime = anchorTime;
         currentFibo.hundredTime = dominantStructure.time;
         currentFibo.isType1 = false;
         currentFibo.isBullish = isCeiling;
         currentFibo.fiboId = fiboId;
         currentStatus = STATUS_FIBO_TYPE2_ACTIVE;
         DrawStatusLabel();
         if(EnableLogging) Print("فیبوناچی نوع دوم رسم شد: ", fiboId);
         return true;
      }
   }

   //--- فیبوناچی نوع اول
   if(EnableFiboType1)
   {
      double minorPrice = 0;
      datetime minorTime = 0;
      bool hasMinorCorrection = FindMinorCorrection(anchorTime, dominantStructure.breakTime, isCeiling, minorPrice, minorTime);
      if(hasMinorCorrection)
      {
         double fiboZero = anchorPrice;
         double fiboHundred = minorPrice;
         string fiboId = "Fibo_Type1_" + TimeToString(dominantStructure.breakTime);
         
         //--- حذف فیبوناچی قبلی
         if(currentFibo.fiboId != "") ObjectDelete(0, currentFibo.fiboId);
         if(currentFibo.fiboId != "") ObjectDelete(0, currentFibo.fiboId + "_EntryZone");

         if(ObjectCreate(0, fiboId, OBJ_FIBO, 0, anchorTime, fiboZero, minorTime, fiboHundred))
         {
            ObjectSetInteger(0, fiboId, OBJPROP_LEVELS, 4);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 0, 0.0);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 1, 1.0);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 2, FiboEntryZoneMin / 100.0);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 3, FiboEntryZoneMax / 100.0);
            ObjectSetInteger(0, fiboId, OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, fiboId, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, fiboId, OBJPROP_WIDTH, 1);

            //--- رسم ناحیه ورود
            double entryZoneMin = fiboZero + (fiboHundred - fiboZero) * (FiboEntryZoneMin / 100.0);
            double entryZoneMax = fiboZero + (fiboHundred - fiboZero) * (FiboEntryZoneMax / 100.0);
            string entryZoneId = fiboId + "_EntryZone";
            ObjectCreate(0, entryZoneId, OBJ_RECTANGLE, 0, anchorTime, entryZoneMin, minorTime, entryZoneMax);
            ObjectSetInteger(0, entryZoneId, OBJPROP_COLOR, EntryZoneColor);
            ObjectSetInteger(0, entryZoneId, OBJPROP_BACK, true);
            ObjectSetInteger(0, entryZoneId, OBJPROP_FILL, true);

            currentFibo.zeroLevel = fiboZero;
            currentFibo.hundredLevel = fiboHundred;
            currentFibo.zeroTime = anchorTime;
            currentFibo.hundredTime = minorTime;
            currentFibo.isType1 = true;
            currentFibo.isBullish = isCeiling;
            currentFibo.fiboId = fiboId;
            currentStatus = STATUS_FIBO_TYPE1_ACTIVE;
            DrawStatusLabel();
            if(EnableLogging) Print("فیبوناچی نوع اول رسم شد: ", fiboId);
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| بررسی شرایط و نگهبانی                                          |
//+------------------------------------------------------------------+
void CFibonacciEngine::CheckConditions()
{
   if(!IsNewCandle()) return;
   if(currentStatus != STATUS_FIBO_TYPE1_ACTIVE && currentStatus != STATUS_FIBO_TYPE2_ACTIVE) return;

   double highPrice = iHigh(_Symbol, _Period, 1);
   double lowPrice = iLow(_Symbol, _Period, 1);

   //--- چک کردن حرمت لنگرگاه
   if(currentFibo.isBullish && lowPrice < currentFibo.zeroLevel)
   {
      if(EnableLogging) Print("تحلیل باطل شد: قیمت به زیر لنگرگاه رفت");
      ResetAnalysis();
      return;
   }
   if(!currentFibo.isBullish && highPrice > currentFibo.zeroLevel)
   {
      if(EnableLogging) Print("تحلیل باطل شد: قیمت به بالای لنگرگاه رفت");
      ResetAnalysis();
      return;
   }

   //--- چک کردن ناحیه ورود
   if(CheckEntryZone(currentFibo.zeroLevel, currentFibo.hundredLevel, FiboEntryZoneMin, FiboEntryZoneMax))
   {
      currentStatus = STATUS_IN_ENTRY_ZONE;
      DrawStatusLabel();
      if(EnableLogging) Print("قیمت وارد ناحیه ورود شد");
   }
   else if(currentStatus == STATUS_IN_ENTRY_ZONE)
   {
      if(EnableLogging) Print("تحلیل باطل شد: قیمت از ناحیه ورود خارج شد");
      ResetAnalysis();
      return;
   }

   //--- آپدیت فیبوناچی‌ها
   if(currentStatus == STATUS_FIBO_TYPE1_ACTIVE && currentFibo.isType1)
   {
      UpdateFiboType1();
   }
   else if(currentStatus == STATUS_FIBO_TYPE2_ACTIVE && !currentFibo.isType1)
   {
      UpdateFiboType2();
   }
}

//+------------------------------------------------------------------+
//| آپدیت فیبوناچی نوع اول                                       |
//+------------------------------------------------------------------+
void CFibonacciEngine::UpdateFiboType1()
{
   double lowPrice = iLow(_Symbol, _Period, 1);
   double highPrice = iHigh(_Symbol, _Period, 1);

   if(currentFibo.isBullish && lowPrice < currentFibo.hundredLevel)
   {
      int lowestShift = iLowest(_Symbol, _Period, MODE_LOW, iBarShift(_Symbol, _Period, currentFibo.hundredTime));
      double newHundredLevel = iLow(_Symbol, _Period, lowestShift);
      datetime newHundredTime = iTime(_Symbol, _Period, lowestShift);

      if(newHundredLevel < currentFibo.hundredLevel)
      {
         ObjectDelete(0, currentFibo.fiboId);
         ObjectDelete(0, currentFibo.fiboId + "_EntryZone");
         
         string fiboId = "Fibo_Type1_" + TimeToString(newHundredTime);
         if(ObjectCreate(0, fiboId, OBJ_FIBO, 0, currentFibo.zeroTime, currentFibo.zeroLevel, newHundredTime, newHundredLevel))
         {
            ObjectSetInteger(0, fiboId, OBJPROP_LEVELS, 4);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 0, 0.0);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 1, 1.0);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 2, FiboEntryZoneMin / 100.0);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 3, FiboEntryZoneMax / 100.0);
            ObjectSetInteger(0, fiboId, OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, fiboId, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, fiboId, OBJPROP_WIDTH, 1);

            //--- آپدیت ناحیه ورود
            double entryZoneMin = currentFibo.zeroLevel + (newHundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMin / 100.0);
            double entryZoneMax = currentFibo.zeroLevel + (newHundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMax / 100.0);
            string entryZoneId = fiboId + "_EntryZone";
            ObjectCreate(0, entryZoneId, OBJ_RECTANGLE, 0, currentFibo.zeroTime, entryZoneMin, newHundredTime, entryZoneMax);
            ObjectSetInteger(0, entryZoneId, OBJPROP_COLOR, EntryZoneColor);
            ObjectSetInteger(0, entryZoneId, OBJPROP_BACK, true);
            ObjectSetInteger(0, entryZoneId, OBJPROP_FILL, true);

            currentFibo.hundredLevel = newHundredLevel;
            currentFibo.hundredTime = newHundredTime;
            currentFibo.fiboId = fiboId;
            if(EnableLogging) Print("فیبوناچی نوع اول آپدیت شد: ", fiboId);
         }
      }
   }
   else if(!currentFibo.isBullish && highPrice > currentFibo.hundredLevel)
   {
      int highestShift = iHighest(_Symbol, _Period, MODE_HIGH, iBarShift(_Symbol, _Period, currentFibo.hundredTime));
      double newHundredLevel = iHigh(_Symbol, _Period, highestShift);
      datetime newHundredTime = iTime(_Symbol, _Period, highestShift);

      if(newHundredLevel > currentFibo.hundredLevel)
      {
         ObjectDelete(0, currentFibo.fiboId);
         ObjectDelete(0, currentFibo.fiboId + "_EntryZone");
         
         string fiboId = "Fibo_Type1_" + TimeToString(newHundredTime);
         if(ObjectCreate(0, fiboId, OBJ_FIBO, 0, currentFibo.zeroTime, currentFibo.zeroLevel, newHundredTime, newHundredLevel))
         {
            ObjectSetInteger(0, fiboId, OBJPROP_LEVELS, 4);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 0, 0.0);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 1, 1.0);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 2, FiboEntryZoneMin / 100.0);
            ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 3, FiboEntryZoneMax / 100.0);
            ObjectSetInteger(0, fiboId, OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, fiboId, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, fiboId, OBJPROP_WIDTH, 1);

            //--- آپدیت ناحیه ورود
            double entryZoneMin = currentFibo.zeroLevel + (newHundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMin / 100.0);
            double entryZoneMax = currentFibo.zeroLevel + (newHundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMax / 100.0);
            string entryZoneId = fiboId + "_EntryZone";
            ObjectCreate(0, entryZoneId, OBJ_RECTANGLE, 0, currentFibo.zeroTime, entryZoneMin, newHundredTime, entryZoneMax);
            ObjectSetInteger(0, entryZoneId, OBJPROP_COLOR, EntryZoneColor);
            ObjectSetInteger(0, entryZoneId, OBJPROP_BACK, true);
            ObjectSetInteger(0, entryZoneId, OBJPROP_FILL, true);

            currentFibo.hundredLevel = newHundredLevel;
            currentFibo.hundredTime = newHundredTime;
            currentFibo.fiboId = fiboId;
            if(EnableLogging) Print("فیبوناچی نوع اول آپدیت شد: ", fiboId);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| آپدیت فیبوناچی نوع دوم                                       |
//+------------------------------------------------------------------+
void CFibonacciEngine::UpdateFiboType2()
{
   double highPrice = iHigh(_Symbol, _Period, 1);
   double lowPrice = iLow(_Symbol, _Period, 1);
   double level150 = currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * 1.5;
   double level200 = currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * 2.0;

   if((currentFibo.isBullish && highPrice >= level150) || (!currentFibo.isBullish && lowPrice <= level150))
   {
      ObjectDelete(0, currentFibo.fiboId);
      ObjectDelete(0, currentFibo.fiboId + "_EntryZone");

      currentFibo.hundredLevel = level150;
      currentFibo.hundredTime = iTime(_Symbol, _Period, 1);
      string fiboId = "Fibo_Type2_" + TimeToString(currentFibo.hundredTime);
      
      if(ObjectCreate(0, fiboId, OBJ_FIBO, 0, currentFibo.zeroTime, currentFibo.zeroLevel, currentFibo.hundredTime, currentFibo.hundredLevel))
      {
         ObjectSetInteger(0, fiboId, OBJPROP_LEVELS, 4);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 0, 0.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 1, 1.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 2, FiboEntryZoneMin / 100.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 3, FiboEntryZoneMax / 100.0);
         ObjectSetInteger(0, fiboId, OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(0, fiboId, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, fiboId, OBJPROP_WIDTH, 1);

         //--- آپدیت ناحیه ورود
         double entryZoneMin = currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMin / 100.0);
         double entryZoneMax = currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMax / 100.0);
         string entryZoneId = fiboId + "_EntryZone";
         ObjectCreate(0, entryZoneId, OBJ_RECTANGLE, 0, currentFibo.zeroTime, entryZoneMin, currentFibo.hundredTime, entryZoneMax);
         ObjectSetInteger(0, entryZoneId, OBJPROP_COLOR, EntryZoneColor);
         ObjectSetInteger(0, entryZoneId, OBJPROP_BACK, true);
         ObjectSetInteger(0, entryZoneId, OBJPROP_FILL, true);

         currentFibo.fiboId = fiboId;
         if(EnableLogging) Print("فیبوناچی نوع دوم به سطح 150 آپدیت شد: ", fiboId);
      }
   }
   else if((currentFibo.isBullish && highPrice >= level200) || (!currentFibo.isBullish && lowPrice <= level200))
   {
      ObjectDelete(0, currentFibo.fiboId);
      ObjectDelete(0, currentFibo.fiboId + "_EntryZone");

      currentFibo.hundredLevel = level200;
      currentFibo.hundredTime = iTime(_Symbol, _Period, 1);
      string fiboId = "Fibo_Type2_" + TimeToString(currentFibo.hundredTime);
      
      if(ObjectCreate(0, fiboId, OBJ_FIBO, 0, currentFibo.zeroTime, currentFibo.zeroLevel, currentFibo.hundredTime, currentFibo.hundredLevel))
      {
         ObjectSetInteger(0, fiboId, OBJPROP_LEVELS, 4);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 0, 0.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 1, 1.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 2, FiboEntryZoneMin / 100.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 3, FiboEntryZoneMax / 100.0);
         ObjectSetInteger(0, fiboId, OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(0, fiboId, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, fiboId, OBJPROP_WIDTH, 1);

         //--- آپدیت ناحیه ورود
         double entryZoneMin = currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMin / 100.0);
         double entryZoneMax = currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMax / 100.0);
         string entryZoneId = fiboId + "_EntryZone";
         ObjectCreate(0, entryZoneId, OBJ_RECTANGLE, 0, currentFibo.zeroTime, entryZoneMin, currentFibo.hundredTime, entryZoneMax);
         ObjectSetInteger(0, entryZoneId, OBJPROP_COLOR, EntryZoneColor);
         ObjectSetInteger(0, entryZoneId, OBJPROP_BACK, true);
         ObjectSetInteger(0, entryZoneId, OBJPROP_FILL, true);

         currentFibo.fiboId = fiboId;
         if(EnableLogging) Print("فیبوناچی نوع دوم به سطح 200 آپدیت شد: ", fiboId);
      }
   }
}

//+------------------------------------------------------------------+
//| دریافت وضعیت فعلی کتابخانه                                     |
//+------------------------------------------------------------------+
ENUM_FIBO_STATUS CFibonacciEngine::GetFiboStatus()
{
   return currentStatus;
}

//+------------------------------------------------------------------+
//| رسم اشیاء گرافیکی                                              |
//+------------------------------------------------------------------+
void CFibonacciEngine::DrawGraphics(string type, double price, datetime time, string id, bool isCeiling = true)
{
   string objName = type + "_" + id;
   if(type == "structure")
   {
      if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, price))
      {
         ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, isCeiling ? 159 : 159);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, isCeiling ? PeakColor : ValleyColor);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
      }
   }
   else if(type == "bos")
   {
      if(ObjectCreate(0, objName, OBJ_TEXT, 0, time, price))
      {
         ObjectSetString(0, objName, OBJPROP_TEXT, "BOS");
         ObjectSetInteger(0, objName, OBJPROP_COLOR, BOSColor);
         ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, FontSize);
         ObjectSetString(0, objName, OBJPROP_FONT, FontName);
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, isCeiling ? ANCHOR_TOP : ANCHOR_BOTTOM);
      }
   }
   else if(type == "anchor")
   {
      datetime endTime = time + PeriodSeconds(TF);
      if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time, price, endTime, price))
      {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, AnchorBlockColor);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      }
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| رسم لیبل وضعیت                                                |
//+------------------------------------------------------------------+
void CFibonacciEngine::DrawStatusLabel()
{
   string statusText;
   switch(currentStatus)
   {
      case STATUS_WAITING:
         statusText = "در انتظار ساختار جدید";
         break;
      case STATUS_FIBO_TYPE1_ACTIVE:
         statusText = "فیبوناچی نوع اول فعال";
         break;
      case STATUS_FIBO_TYPE2_ACTIVE:
         statusText = "فیبوناچی نوع دوم فعال";
         break;
      case STATUS_IN_ENTRY_ZONE:
         statusText = "در ناحیه ورود";
         break;
      case STATUS_INVALID:
         statusText = "تحلیل باطل شده";
         break;
   }
   ObjectSetString(0, statusLabelName, OBJPROP_TEXT, statusText);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| پاک کردن اشیاء گرافیکی قدیمی                                  |
//+------------------------------------------------------------------+
void CFibonacciEngine::ClearOldGraphics()
{
   ObjectsDeleteAll(0, -1, -1);
   if(EnableLogging) Print("اشیاء گرافیکی قدیمی پاک شدند");
}

//+------------------------------------------------------------------+
//| پیدا کردن اصلاح مینور                                          |
//+------------------------------------------------------------------+
bool CFibonacciEngine::FindMinorCorrection(datetime startTime, datetime endTime, bool isBullish, double &minorPrice, datetime &minorTime)
{
   int startShift = iBarShift(_Symbol, TF, endTime);
   int endShift = iBarShift(_Symbol, TF, startTime);
   if(startShift >= endShift) return false;

   for(int i = startShift; i < endShift; i++)
   {
      bool isMinorPeak = true;
      bool isMinorValley = true;
      for(int j = 1; j <= Lookback; j++)
      {
         if(i - j >= startShift && iHigh(_Symbol, TF, i - j) >= iHigh(_Symbol, TF, i)) isMinorPeak = false;
         if(i + j < endShift && iHigh(_Symbol, TF, i + j) >= iHigh(_Symbol, TF, i)) isMinorPeak = false;
         if(i - j >= startShift && iLow(_Symbol, TF, i - j) <= iLow(_Symbol, TF, i)) isMinorValley = false;
         if(i + j < endShift && iLow(_Symbol, TF, i + j) <= iLow(_Symbol, TF, i)) isMinorValley = false;
      }
      if(isBullish && isMinorValley)
      {
         minorPrice = iLow(_Symbol, TF, i);
         minorTime = iTime(_Symbol, TF, i);
         //--- بررسی پولبک به ناحیه 50-68 درصد
         double fiboZero = iLow(_Symbol, TF, iBarShift(_Symbol, TF, startTime));
         double fiboHundred = iHigh(_Symbol, TF, i);
         double entryZoneMin = fiboZero + (fiboHundred - fiboZero) * (FiboEntryZoneMin / 100.0);
         double entryZoneMax = fiboZero + (fiboHundred - fiboZero) * (FiboEntryZoneMax / 100.0);
         for(int k = i; k >= startShift; k--)
         {
            if(iLow(_Symbol, TF, k) >= entryZoneMin && iLow(_Symbol, TF, k) <= entryZoneMax)
            {
               if(EnableLogging) Print("اصلاح مینور (کف) پیدا شد: ", minorPrice, " زمان: ", TimeToString(minorTime));
               return true;
            }
         }
      }
      else if(!isBullish && isMinorPeak)
      {
         minorPrice = iHigh(_Symbol, TF, i);
         minorTime = iTime(_Symbol, TF, i);
         //--- بررسی پولبک به ناحیه 50-68 درصد
         double fiboZero = iHigh(_Symbol, TF, iBarShift(_Symbol, TF, startTime));
         double fiboHundred = iLow(_Symbol, TF, i);
         double entryZoneMin = fiboHundred + (fiboZero - fiboHundred) * (FiboEntryZoneMin / 100.0);
         double entryZoneMax = fiboHundred + (fiboZero - fiboHundred) * (FiboEntryZoneMax / 100.0);
         for(int k = i; k >= startShift; k--)
         {
            if(iHigh(_Symbol, TF, k) >= entryZoneMin && iHigh(_Symbol, TF, k) <= entryZoneMax)
            {
               if(EnableLogging) Print("اصلاح مینور (سقف) پیدا شد: ", minorPrice, " زمان: ", TimeToString(minorTime));
               return true;
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| بررسی ناحیه ورود                                               |
//+------------------------------------------------------------------+
bool CFibonacciEngine::CheckEntryZone(double zeroLevel, double hundredLevel, double minPercent, double maxPercent)
{
   double entryZoneMin = zeroLevel + (hundredLevel - zeroLevel) * (minPercent / 100.0);
   double entryZoneMax = zeroLevel + (hundredLevel - zeroLevel) * (maxPercent / 100.0);
   double closePrice = iClose(_Symbol, _Period, 1);
   return closePrice >= entryZoneMin && closePrice <= entryZoneMax;
}

//+------------------------------------------------------------------+
//| ریست تحلیل                                                    |
//+------------------------------------------------------------------+
void CFibonacciEngine::ResetAnalysis()
{
   ClearOldGraphics();
   currentFibo.zeroLevel = 0;
   currentFibo.hundredLevel = 0;
   currentFibo.zeroTime = 0;
   currentFibo.hundredTime = 0;
   currentFibo.isType1 = false;
   currentFibo.isBullish = true;
   currentFibo.fiboId = "";
   currentStatus = STATUS_WAITING;
   DrawStatusLabel();
   if(EnableLogging) Print("تحلیل ریست شد");
}
//+------------------------------------------------------------------+
