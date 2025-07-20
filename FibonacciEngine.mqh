//+------------------------------------------------------------------+
//| SimpleFibonacciEngine.mqh                                       |
//| کتابخانه ساده‌شده برای رسم فیبوناچی نوع دوم (اکستنشن)        |
//| شناسایی سقف‌ها، کف‌ها، شکست‌ها و نقاط ورود با اندیکاتور Fineflow  |
//| نسخه بهینه‌شده با محاسبه یک‌بار لنگرگاه و حالت تمرکز         |
//| نسخه: 1.00                                                     |
//| تاریخ: 2025-07-20                                             |
//+------------------------------------------------------------------+

#property copyright "Your Name"
#property version   "1.00"
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
input int MaxScanDepth = 50; // حداکثر کندل‌ها برای اسکن اولیه
input int MaxArraySize = 20; // حداکثر اندازه آرایه‌های سقف و کف
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

input group "تنظیمات فیبوناچی"
input double FiboEntryZoneMin = 50.0; // حداقل درصد ناحیه ورود (50%)
input double FiboEntryZoneMax = 68.0; // حداکثر درصد ناحیه ورود (68%)

input group "تنظیمات گرافیکی"
input color PeakColor = clrRed; // رنگ علامت سقف (ستاره)
input color ValleyColor = clrGreen; // رنگ علامت کف (ستاره)
input color BOSColor = clrBlue; // رنگ نوشته BOS
input color AnchorBlockColor = clrYellow; // رنگ مستطیل اوردر بلاک میانی
input color EntryZoneColor = clrLimeGreen; // رنگ ناحیه ورود
input color FiboType2ColorUp = clrGreen; // رنگ فیبوناچی نوع دوم (صعودی)
input color FiboType2ColorDown = clrRed; // رنگ فیبوناچی نوع دوم (نزولی)
input color FiboType2TempColor = clrLightGray; // رنگ فیبوناچی موقت
input int FontSize = 10; // اندازه فونت نوشته BOS و وضعیت
input string FontName = "Arial"; // نام فونت

//--- تعریف enums برای مدیریت وضعیت
enum ENUM_FIBO_STATUS {
   STATUS_WAITING,           // در انتظار ساختار جدید
   STATUS_ANALYSIS_IN_PROGRESS, // تحلیل در جریان
   STATUS_FIBO_TYPE2_TEMP,   // فیبوناچی نوع دوم موقت
   STATUS_FIBO_TYPE2_ACTIVE, // فیبوناچی نوع دوم فعال
   STATUS_IN_ENTRY_ZONE,     // در ناحیه ورود
   STATUS_INVALID            // تحلیل باطل شده
};

//--- ساختار برای ذخیره اطلاعات سقف، کف و لنگرگاه
struct PeakValley {
   double price;   // قیمت سقف، کف یا لنگرگاه
   datetime time;  // زمان
   string id;      // شناسه منحصربه‌فرد
   datetime breakTime; // زمان شکست
};

//--- ساختار برای ذخیره اطلاعات فیبوناچی
struct FiboStructure {
   double zeroLevel;    // سطح صفر فیبوناچی
   double hundredLevel; // سطح 100 فیبوناچی
   datetime zeroTime;   // زمان سطح صفر
   datetime hundredTime;// زمان سطح 100
   bool isBullish;      // جهت (صعودی یا نزولی)
   string fiboId;       // شناسه فیبوناچی
   bool isTemporary;    // آیا فیبوناچی موقت است؟
};

//--- کلاس اصلی کتابخانه
class CSimpleFibonacciEngine {
private:
   //--- متغیرهای داخلی
   int handleFineflow;          // هندل اندیکاتور Fineflow
   PeakValley m_ceilings[];     // آرایه سقف‌های در انتظار
   PeakValley m_valleys[];      // آرایه کف‌های در انتظار
   PeakValley m_lastBrokenStructure; // آخرین سقف/کف شکسته‌شده
   PeakValley m_anchorPoint;    // لنگرگاه (اوردر بلاک میانی)
   FiboStructure currentFibo;   // فیبوناچی فعلی
   ENUM_FIBO_STATUS currentStatus; // وضعیت فعلی کتابخانه
   datetime lastCandleTime;     // زمان آخرین کندل پردازش‌شده
   datetime lastStructureTime;  // زمان آخرین سقف/کف پیدا‌شده
   string statusLabelName;      // نام لیبل وضعیت

   //--- توابع کمکی
   bool IsNewCandle();
   void ManageDataArrays();
   void DrawGraphics(string type, double price, datetime time, string id, bool isCeiling = true, double highPrice = 0, double lowPrice = 0);
   void DrawStatusLabel();
   void ClearOldGraphics(datetime beforeTime = 0);
   bool IdentifyAnchorPoint();
   void ActivateFiboType2();
   bool CheckEntryZone(double zeroLevel, double hundredLevel, double minPercent, double maxPercent);
   void ResetAnalysis();
   void UpdateFiboType2();

public:
   //--- سازنده و دفع‌کننده
   CSimpleFibonacciEngine();
   ~CSimpleFibonacciEngine();

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
CSimpleFibonacciEngine::CSimpleFibonacciEngine()
{
   handleFineflow = INVALID_HANDLE;
   ArraySetAsSeries(m_ceilings, true);
   ArraySetAsSeries(m_valleys, true);
   m_lastBrokenStructure.price = 0;
   m_lastBrokenStructure.time = 0;
   m_lastBrokenStructure.id = "";
   m_lastBrokenStructure.breakTime = 0;
   m_anchorPoint.price = 0;
   m_anchorPoint.time = 0;
   m_anchorPoint.id = "";
   m_anchorPoint.breakTime = 0;
   currentStatus = STATUS_WAITING;
   lastCandleTime = 0;
   lastStructureTime = 0;
   statusLabelName = "SimpleFiboEngine_Status";
   currentFibo.zeroLevel = 0;
   currentFibo.hundredLevel = 0;
   currentFibo.zeroTime = 0;
   currentFibo.hundredTime = 0;
   currentFibo.isBullish = true;
   currentFibo.fiboId = "";
   currentFibo.isTemporary = false;
}

//+------------------------------------------------------------------+
//| دفع‌کننده کلاس                                                 |
//+------------------------------------------------------------------+
CSimpleFibonacciEngine::~CSimpleFibonacciEngine()
{
   if(handleFineflow != INVALID_HANDLE)
      IndicatorRelease(handleFineflow);
   ObjectsDeleteAll(0, -1, -1);
}

//+------------------------------------------------------------------+
//| تابع مقداردهی اولیه                                            |
//+------------------------------------------------------------------+
bool CSimpleFibonacciEngine::Init()
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

   //--- پیدا کردن اولین سقف یا کف
   double highBuffer[1];
   double lowBuffer[1];
   datetime times[1];
   for(int i = 1; i <= MaxScanDepth; i++)
   {
      if(CopyBuffer(handleFineflow, 0, i, 1, highBuffer) > 0 &&
         CopyBuffer(handleFineflow, 1, i, 1, lowBuffer) > 0 &&
         CopyTime(_Symbol, TF, i, 1, times) > 0)
      {
         if(highBuffer[0] != EMPTY_VALUE && highBuffer[0] > 0)
         {
            lastStructureTime = times[0];
            int size = ArraySize(m_ceilings);
            ArrayResize(m_ceilings, size + 1);
            m_ceilings[size].price = highBuffer[0];
            m_ceilings[size].time = times[0];
            m_ceilings[size].id = "C_" + TimeToString(times[0]);
            m_ceilings[size].breakTime = 0;
            if(EnableLogging) Print("اولین سقف پیدا شد: ", m_ceilings[size].id, " قیمت: ", highBuffer[0], " زمان: ", TimeToString(times[0]));
            break;
         }
         if(lowBuffer[0] != EMPTY_VALUE && lowBuffer[0] > 0)
         {
            lastStructureTime = times[0];
            int size = ArraySize(m_valleys);
            ArrayResize(m_valleys, size + 1);
            m_valleys[size].price = lowBuffer[0];
            m_valleys[size].time = times[0];
            m_valleys[size].id = "V_" + TimeToString(times[0]);
            m_valleys[size].breakTime = 0;
            if(EnableLogging) Print("اولین کف پیدا شد: ", m_valleys[size].id, " قیمت: ", lowBuffer[0], " زمان: ", TimeToString(times[0]));
            break;
         }
      }
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
bool CSimpleFibonacciEngine::IsNewCandle()
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
void CSimpleFibonacciEngine::ManageDataArrays()
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
//| شناسایی لنگرگاه                                                |
//+------------------------------------------------------------------+
bool CSimpleFibonacciEngine::IdentifyAnchorPoint()
{
   if(m_lastBrokenStructure.price == 0) return false;

   bool isCeiling = m_lastBrokenStructure.price > (ArraySize(m_valleys) > 0 ? m_valleys[0].price : 0);
   double anchorPrice = 0;
   datetime anchorTime = 0;
   double anchorHigh = 0;
   double anchorLow = 0;
   int startShift = iBarShift(_Symbol, TF, m_lastBrokenStructure.breakTime);
   int endShift = iBarShift(_Symbol, TF, m_lastBrokenStructure.time);
   for(int j = startShift; j <= endShift; j++)
   {
      double currentPrice = isCeiling ? iLow(_Symbol, TF, j) : iHigh(_Symbol, TF, j);
      if(anchorPrice == 0 || (isCeiling && currentPrice < anchorPrice) || (!isCeiling && currentPrice > anchorPrice))
      {
         anchorPrice = currentPrice;
         anchorTime = iTime(_Symbol, TF, j);
         anchorHigh = iHigh(_Symbol, TF, j);
         anchorLow = iLow(_Symbol, TF, j);
      }
   }
   if(anchorPrice > 0)
   {
      m_anchorPoint.price = anchorPrice;
      m_anchorPoint.time = anchorTime;
      m_anchorPoint.id = m_lastBrokenStructure.id + "_Anchor";
      m_anchorPoint.breakTime = 0;
      DrawGraphics("anchor", anchorPrice, anchorTime, m_lastBrokenStructure.id + "_Anchor", isCeiling, anchorHigh, anchorLow);
      if(EnableLogging) Print("لنگرگاه شناسایی شد: ", m_anchorPoint.id, " قیمت: ", anchorPrice, " زمان: ", TimeToString(anchorTime));
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| نقشه‌بردار برای شناسایی ساختارها                              |
//+------------------------------------------------------------------+
void CSimpleFibonacciEngine::ScoutForStructure()
{
   if(!IsNewCandle()) return;

   //--- حالت تمرکز: فقط نگهبانی انجام بده
   if(currentStatus == STATUS_ANALYSIS_IN_PROGRESS)
   {
      CheckConditions();
      return;
   }

   //--- جمع‌آوری سقف‌ها و کف‌ها از کندل بسته‌شده (اندیس 1)
   double highBuffer[1];
   double lowBuffer[1];
   datetime times[1];
   int i = 1;
   while(true)
   {
      if(CopyBuffer(handleFineflow, 0, i, 1, highBuffer) > 0 &&
         CopyBuffer(handleFineflow, 1, i, 1, lowBuffer) > 0 &&
         CopyTime(_Symbol, TF, i, 1, times) > 0)
      {
         if(times[0] <= lastStructureTime) break;

         if(highBuffer[0] != EMPTY_VALUE && highBuffer[0] > 0)
         {
            lastStructureTime = times[0];
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
            lastStructureTime = times[0];
            int size = ArraySize(m_valleys);
            ArrayResize(m_valleys, size + 1);
            m_valleys[size].price = lowBuffer[0];
            m_valleys[size].time = times[0];
            m_valleys[size].id = "V_" + TimeToString(times[0]);
            m_valleys[size].breakTime = 0;
            if(EnableLogging) Print("کف جدید: ", m_valleys[size].id, " قیمت: ", lowBuffer[0], " زمان: ", TimeToString(times[0]));
         }
      }
      i++;
      if(i > MaxScanDepth) break;
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
      for(int j = 0; j < ArraySize(m_ceilings); j++)
      {
         if(m_ceilings[j].breakTime == 0 && highPrice > m_ceilings[j].price)
         {
            m_ceilings[j].breakTime = currentTime;
            if(EnableLogging) Print("شکست سقف: ", m_ceilings[j].id, " در زمان ", TimeToString(currentTime));
            if(dominantStructure.breakTime == 0 || m_ceilings[j].breakTime > dominantStructure.breakTime)
            {
               dominantStructure = m_ceilings[j];
               newBreakFound = true;
            }
         }
      }
      for(int j = 0; j < ArraySize(m_valleys); j++)
      {
         if(m_valleys[j].breakTime == 0 && lowPrice < m_valleys[j].price)
         {
            m_valleys[j].breakTime = currentTime;
            if(EnableLogging) Print("شکست کف: ", m_valleys[j].id, " در زمان ", TimeToString(currentTime));
            if(dominantStructure.breakTime == 0 || m_valleys[j].breakTime > dominantStructure.breakTime)
            {
               dominantStructure = m_valleys[j];
               newBreakFound = true;
            }
         }
      }
   }
   else // BREAK_CONFIRMED
   {
      static PeakValley pendingBreaks[];
      ArraySetAsSeries(pendingBreaks, true);
      for(int j = 0; j < ArraySize(m_ceilings); j++)
      {
         if(m_ceilings[j].breakTime == 0 && highPrice > m_ceilings[j].price)
         {
            int size = ArraySize(pendingBreaks);
            ArrayResize(pendingBreaks, size + 1);
            pendingBreaks[size] = m_ceilings[j];
            pendingBreaks[size].breakTime = currentTime + ConfirmationCandles * PeriodSeconds(TF);
            if(EnableLogging) Print("شکست در انتظار تأیید سقف: ", m_ceilings[j].id);
         }
      }
      for(int j = 0; j < ArraySize(m_valleys); j++)
      {
         if(m_valleys[j].breakTime == 0 && lowPrice < m_valleys[j].price)
         {
            int size = ArraySize(pendingBreaks);
            ArrayResize(pendingBreaks, size + 1);
            pendingBreaks[size] = m_valleys[j];
            pendingBreaks[size].breakTime = currentTime + ConfirmationCandles * PeriodSeconds(TF);
            if(EnableLogging) Print("شکست در انتظار تأیید کف: ", m_valleys[j].id);
         }
      }
      for(int j = ArraySize(pendingBreaks) - 1; j >= 0; j--)
      {
         if(pendingBreaks[j].breakTime > 0 && currentTime >= pendingBreaks[j].breakTime)
         {
            if(pendingBreaks[j].price > (ArraySize(m_valleys) > 0 ? m_valleys[0].price : 0)) // سقف
            {
               for(int k = 0; k < ArraySize(m_ceilings); k++)
               {
                  if(m_ceilings[k].id == pendingBreaks[j].id)
                  {
                     m_ceilings[k].breakTime = currentTime;
                     if(EnableLogging) Print("شکست تأیید شده سقف: ", m_ceilings[k].id);
                     if(dominantStructure.breakTime == 0 || m_ceilings[k].breakTime > dominantStructure.breakTime)
                     {
                        dominantStructure = m_ceilings[k];
                        newBreakFound = true;
                     }
                     break;
                  }
               }
            }
            else // کف
            {
               for(int k = 0; k < ArraySize(m_valleys); k++)
               {
                  if(m_valleys[k].id == pendingBreaks[j].id)
                  {
                     m_valleys[k].breakTime = currentTime;
                     if(EnableLogging) Print("شکست تأیید شده کف: ", m_valleys[k].id);
                     if(dominantStructure.breakTime == 0 || m_valleys[k].breakTime > dominantStructure.breakTime)
                     {
                        dominantStructure = m_valleys[k];
                        newBreakFound = true;
                     }
                     break;
                  }
               }
            }
            ArrayRemove(pendingBreaks, j, 1);
         }
      }
   }

   //--- مدیریت شکست و گرافیک‌ها
   if(newBreakFound)
   {
      m_lastBrokenStructure = dominantStructure;
      if(EnableLogging) Print("آخرین ساختار شکسته‌شده: ", m_lastBrokenStructure.id, " زمان: ", TimeToString(m_lastBrokenStructure.breakTime));

      for(int j = ArraySize(m_ceilings) - 1; j >= 0; j--)
      {
         if(m_ceilings[j].id == dominantStructure.id)
         {
            ArrayRemove(m_ceilings, j, 1);
            if(EnableLogging) Print("سقف شکسته‌شده از آرایه حذف شد: ", dominantStructure.id);
            break;
         }
      }
      for(int j = ArraySize(m_valleys) - 1; j >= 0; j--)
      {
         if(m_valleys[j].id == dominantStructure.id)
         {
            ArrayRemove(m_valleys, j, 1);
            if(EnableLogging) Print("کف شکسته‌شده از آرایه حذف شد: ", dominantStructure.id);
            break;
         }
      }

      ClearOldGraphics(m_lastBrokenStructure.time);
      ResetAnalysis();

      bool isCeiling = m_lastBrokenStructure.price > (ArraySize(m_valleys) > 0 ? m_valleys[0].price : 0);
      DrawGraphics("structure", m_lastBrokenStructure.price, m_lastBrokenStructure.time, m_lastBrokenStructure.id, isCeiling);
      datetime bosTime = (BreakType == BREAK_SIMPLE) ? m_lastBrokenStructure.breakTime : currentTime;
      DrawGraphics("bos", iClose(_Symbol, _Period, iBarShift(_Symbol, _Period, bosTime)), bosTime, m_lastBrokenStructure.id + "_BOS", isCeiling);

      //--- شناسایی و رسم لنگرگاه
      IdentifyAnchorPoint();
      currentStatus = STATUS_WAITING;
      DrawStatusLabel();
   }
}

//+------------------------------------------------------------------+
//| تحلیل و رسم فیبوناچی                                          |
//+------------------------------------------------------------------+
bool CSimpleFibonacciEngine::AnalyzeAndDrawFibo(bool isBuy)
{
   if(m_lastBrokenStructure.price == 0 || m_anchorPoint.price == 0) return false;

   bool isCeiling = m_lastBrokenStructure.price > (ArraySize(m_valleys) > 0 ? m_valleys[0].price : 0);
   if((isBuy && !isCeiling) || (!isBuy && isCeiling))
   {
      if(EnableLogging) Print("جهت درخواست با ساختار بازار هماهنگ نیست");
      return false;
   }

   //--- ورود به حالت تمرکز
   currentStatus = STATUS_ANALYSIS_IN_PROGRESS;
   DrawStatusLabel();

   //--- رسم فیبوناچی نوع دوم
   ActivateFiboType2();
   return true;
}

//+------------------------------------------------------------------+
//| فعال‌سازی فیبوناچی نوع دوم                                    |
//+------------------------------------------------------------------+
void CSimpleFibonacciEngine::ActivateFiboType2()
{
   bool isCeiling = m_lastBrokenStructure.price > (ArraySize(m_valleys) > 0 ? m_valleys[0].price : 0);
   double fiboZero = isCeiling ? iLow(_Symbol, TF, iBarShift(_Symbol, TF, m_anchorPoint.time)) : 
                                 iHigh(_Symbol, TF, iBarShift(_Symbol, TF, m_anchorPoint.time));
   double fiboHundred = m_lastBrokenStructure.price;
   string fiboId = "Fibo_Type2_Temp_" + TimeToString(m_lastBrokenStructure.breakTime);

   if(currentFibo.fiboId != "") ObjectDelete(0, currentFibo.fiboId);
   if(currentFibo.fiboId != "") ObjectDelete(0, currentFibo.fiboId + "_EntryZone");

   if(ObjectCreate(0, fiboId, OBJ_FIBO, 0, m_anchorPoint.time, fiboZero, m_lastBrokenStructure.time, fiboHundred))
   {
      ObjectSetInteger(0, fiboId, OBJPROP_LEVELS, 6);
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 0, 0.0);
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 1, 1.0);
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 2, FiboEntryZoneMin / 100.0);
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 3, FiboEntryZoneMax / 100.0);
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 4, -0.5);
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 5, -1.0);
      ObjectSetInteger(0, fiboId, OBJPROP_COLOR, FiboType2TempColor);
      ObjectSetInteger(0, fiboId, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, fiboId, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, fiboId, OBJPROP_RAY_RIGHT, false);

      double entryZoneMin = isCeiling ? 
                           fiboHundred + (fiboZero - fiboHundred) * (FiboEntryZoneMin / 100.0) : 
                           fiboZero + (fiboHundred - fiboZero) * (FiboEntryZoneMin / 100.0);
      double entryZoneMax = isCeiling ? 
                           fiboHundred + (fiboZero - fiboHundred) * (FiboEntryZoneMax / 100.0) : 
                           fiboZero + (fiboHundred - fiboZero) * (FiboEntryZoneMax / 100.0);
      string entryZoneId = fiboId + "_EntryZone";
      ObjectCreate(0, entryZoneId, OBJ_RECTANGLE, 0, m_anchorPoint.time, entryZoneMin, m_lastBrokenStructure.time, entryZoneMax);
      ObjectSetInteger(0, entryZoneId, OBJPROP_COLOR, EntryZoneColor);
      ObjectSetInteger(0, entryZoneId, OBJPROP_BACK, true);
      ObjectSetInteger(0, entryZoneId, OBJPROP_FILL, true);

      currentFibo.zeroLevel = fiboZero;
      currentFibo.hundredLevel = fiboHundred;
      currentFibo.zeroTime = m_anchorPoint.time;
      currentFibo.hundredTime = m_lastBrokenStructure.time;
      currentFibo.isBullish = !isCeiling;
      currentFibo.fiboId = fiboId;
      currentFibo.isTemporary = true;
      currentStatus = STATUS_FIBO_TYPE2_TEMP;
      DrawStatusLabel();
      if(EnableLogging) Print("فیبوناچی نوع دوم موقت رسم شد: ", fiboId);
   }
}

//+------------------------------------------------------------------+
//| بررسی شرایط و نگهبانی                                          |
//+------------------------------------------------------------------+
void CSimpleFibonacciEngine::CheckConditions()
{
   if(!IsNewCandle()) return;
   if(currentStatus != STATUS_FIBO_TYPE2_TEMP && currentStatus != STATUS_FIBO_TYPE2_ACTIVE) return;

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

   //--- آپدیت فیبوناچی نوع دوم
   UpdateFiboType2();
}

//+------------------------------------------------------------------+
//| آپدیت فیبوناچی نوع دوم                                       |
//+------------------------------------------------------------------+
void CSimpleFibonacciEngine::UpdateFiboType2()
{
   double highPrice = iHigh(_Symbol, _Period, 1);
   double lowPrice = iLow(_Symbol, _Period, 1);
   double level150 = currentFibo.isBullish ? 
                     currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * 1.5 : 
                     currentFibo.zeroLevel - (currentFibo.zeroLevel - currentFibo.hundredLevel) * 1.5;
   double level200 = currentFibo.isBullish ? 
                     currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * 2.0 : 
                     currentFibo.zeroLevel - (currentFibo.zeroLevel - currentFibo.hundredLevel) * 2.0;

   if((currentFibo.isBullish && highPrice >= level150) || (!currentFibo.isBullish && lowPrice <= level150))
   {
      ObjectDelete(0, currentFibo.fiboId);
      ObjectDelete(0, currentFibo.fiboId + "_EntryZone");

      currentFibo.hundredLevel = level150;
      currentFibo.hundredTime = iTime(_Symbol, _Period, 1);
      string fiboId = "Fibo_Type2_" + TimeToString(currentFibo.hundredTime);

      if(ObjectCreate(0, fiboId, OBJ_FIBO, 0, currentFibo.zeroTime, currentFibo.zeroLevel, currentFibo.hundredTime, currentFibo.hundredLevel))
      {
         ObjectSetInteger(0, fiboId, OBJPROP_LEVELS, 6);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 0, 0.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 1, 1.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 2, FiboEntryZoneMin / 100.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 3, FiboEntryZoneMax / 100.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 4, -0.5);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 5, -1.0);
         ObjectSetInteger(0, fiboId, OBJPROP_COLOR, currentFibo.isBullish ? FiboType2ColorUp : FiboType2ColorDown);
         ObjectSetInteger(0, fiboId, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, fiboId, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, fiboId, OBJPROP_RAY_RIGHT, true);

         double entryZoneMin = currentFibo.isBullish ? 
                              currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMin / 100.0) : 
                              currentFibo.hundredLevel + (currentFibo.zeroLevel - currentFibo.hundredLevel) * (FiboEntryZoneMin / 100.0);
         double entryZoneMax = currentFibo.isBullish ? 
                              currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMax / 100.0) : 
                              currentFibo.hundredLevel + (currentFibo.zeroLevel - currentFibo.hundredLevel) * (FiboEntryZoneMax / 100.0);
         string entryZoneId = fiboId + "_EntryZone";
         ObjectCreate(0, entryZoneId, OBJ_RECTANGLE, 0, currentFibo.zeroTime, entryZoneMin, currentFibo.hundredTime, entryZoneMax);
         ObjectSetInteger(0, entryZoneId, OBJPROP_COLOR, EntryZoneColor);
         ObjectSetInteger(0, entryZoneId, OBJPROP_BACK, true);
         ObjectSetInteger(0, entryZoneId, OBJPROP_FILL, true);

         currentFibo.fiboId = fiboId;
         currentFibo.isTemporary = false;
         currentStatus = STATUS_FIBO_TYPE2_ACTIVE;
         DrawStatusLabel();
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
         ObjectSetInteger(0, fiboId, OBJPROP_LEVELS, 6);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 0, 0.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 1, 1.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 2, FiboEntryZoneMin / 100.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 3, FiboEntryZoneMax / 100.0);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 4, -0.5);
         ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 5, -1.0);
         ObjectSetInteger(0, fiboId, OBJPROP_COLOR, currentFibo.isBullish ? FiboType2ColorUp : FiboType2ColorDown);
         ObjectSetInteger(0, fiboId, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, fiboId, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, fiboId, OBJPROP_RAY_RIGHT, true);

         double entryZoneMin = currentFibo.isBullish ? 
                              currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMin / 100.0) : 
                              currentFibo.hundredLevel + (currentFibo.zeroLevel - currentFibo.hundredLevel) * (FiboEntryZoneMin / 100.0);
         double entryZoneMax = currentFibo.isBullish ? 
                              currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMax / 100.0) : 
                              currentFibo.hundredLevel + (currentFibo.zeroLevel - currentFibo.hundredLevel) * (FiboEntryZoneMax / 100.0);
         string entryZoneId = fiboId + "_EntryZone";
         ObjectCreate(0, entryZoneId, OBJ_RECTANGLE, 0, currentFibo.zeroTime, entryZoneMin, currentFibo.hundredTime, entryZoneMax);
         ObjectSetInteger(0, entryZoneId, OBJPROP_COLOR, EntryZoneColor);
         ObjectSetInteger(0, entryZoneId, OBJPROP_BACK, true);
         ObjectSetInteger(0, entryZoneId, OBJPROP_FILL, true);

         currentFibo.fiboId = fiboId;
         currentFibo.isTemporary = false;
         currentStatus = STATUS_FIBO_TYPE2_ACTIVE;
         DrawStatusLabel();
         if(EnableLogging) Print("فیبوناچی نوع دوم به سطح 200 آپدیت شد: ", fiboId);
      }
   }
}

//+------------------------------------------------------------------+
//| دریافت وضعیت فعلی کتابخانه                                     |
//+------------------------------------------------------------------+
ENUM_FIBO_STATUS CSimpleFibonacciEngine::GetFiboStatus()
{
   return currentStatus;
}

//+------------------------------------------------------------------+
//| رسم اشیاء گرافیکی                                              |
//+------------------------------------------------------------------+
void CSimpleFibonacciEngine::DrawGraphics(string type, double price, datetime time, string id, bool isCeiling = true, double highPrice = 0, double lowPrice = 0)
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
      if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time, highPrice, endTime, lowPrice))
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
void CSimpleFibonacciEngine::DrawStatusLabel()
{
   string statusText;
   switch(currentStatus)
   {
      case STATUS_WAITING:
         statusText = "در انتظار ساختار جدید";
         break;
      case STATUS_ANALYSIS_IN_PROGRESS:
         statusText = "تحلیل در جریان";
         break;
      case STATUS_FIBO_TYPE2_TEMP:
         statusText = "فیبوناچی نوع دوم موقت";
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
   ObjectSetString(0, statusLabelName, OBJPROP_TEXT, "وضعیت: " + statusText);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| پاک‌سازی گرافیک‌های قدیمی                                      |
//+------------------------------------------------------------------+
void CSimpleFibonacciEngine::ClearOldGraphics(datetime beforeTime = 0)
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "structure_") == 0 || StringFind(name, "bos_") == 0 || StringFind(name, "anchor_") == 0)
      {
         datetime objTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
         if(beforeTime == 0 || objTime < beforeTime)
            ObjectDelete(0, name);
      }
   }
   if(currentFibo.fiboId != "")
   {
      ObjectDelete(0, currentFibo.fiboId);
      ObjectDelete(0, currentFibo.fiboId + "_EntryZone");
      currentFibo.fiboId = "";
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| بررسی ناحیه ورود                                               |
//+------------------------------------------------------------------+
bool CSimpleFibonacciEngine::CheckEntryZone(double zeroLevel, double hundredLevel, double minPercent, double maxPercent)
{
   double highPrice = iHigh(_Symbol, _Period, 1);
   double lowPrice = iLow(_Symbol, _Period, 1);
   double entryZoneMin = currentFibo.isBullish ? 
                        zeroLevel + (hundredLevel - zeroLevel) * (minPercent / 100.0) : 
                        hundredLevel + (zeroLevel - hundredLevel) * (minPercent / 100.0);
   double entryZoneMax = currentFibo.isBullish ? 
                        zeroLevel + (hundredLevel - zeroLevel) * (maxPercent / 100.0) : 
                        hundredLevel + (zeroLevel - hundredLevel) * (maxPercent / 100.0);
   return (highPrice >= entryZoneMin && lowPrice <= entryZoneMax);
}

//+------------------------------------------------------------------+
//| بازنشانی تحلیل                                                |
//+------------------------------------------------------------------+
void CSimpleFibonacciEngine::ResetAnalysis()
{
   if(currentFibo.fiboId != "")
   {
      ObjectDelete(0, currentFibo.fiboId);
      ObjectDelete(0, currentFibo.fiboId + "_EntryZone");
   }
   currentFibo.zeroLevel = 0;
   currentFibo.hundredLevel = 0;
   currentFibo.zeroTime = 0;
   currentFibo.hundredTime = 0;
   currentFibo.isBullish = true;
   currentFibo.fiboId = "";
   currentFibo.isTemporary = false;
   currentStatus = STATUS_WAITING;
   DrawStatusLabel();
   if(EnableLogging) Print("تحلیل بازنشانی شد");
}
