//+------------------------------------------------------------------+
//| SimpleFibonacciEngine.mqh                                       |
//| کتابخانه ساده‌شده برای رسم فیبوناچی نوع دوم (اکستنشن)        |
//| شناسایی سقف‌ها، کف‌ها، شکست‌ها و نقاط ورود با اندیکاتور Fineflow  |
//| نسخه بهینه‌شده با محاسبه یک‌بار لنگرگاه و حالت تمرکز         |
//| نسخه: 2.00                                                     |
//| تاریخ: 2025-07-20                                             |
//+------------------------------------------------------------------+

#property copyright "Your Name"
#property version   "2.00"
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
   bool isCeilingBreak; // آیا شکست از نوع سقف است؟
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
   bool AnalyzeAndDrawFibo(bool isCeilingBreak);
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
   currentFibo.isCeilingBreak = true;
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
   if(EnableLogging) Print("شروع مقداردهی اولیه کتابخانه...");
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
      if(EnableLogging) Print("خطا: اندیکاتور Fineflow بارگذاری نشد!");
      return false;
   }
   if(EnableLogging) Print("اندیکاتور Fineflow با موفقیت بارگذاری شد.");

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
            if(EnableLogging) Print("اولین سقف پیدا شد: ID=", m_ceilings[size].id, ", قیمت=", highBuffer[0], ", زمان=", TimeToString(times[0]));
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
            if(EnableLogging) Print("اولین کف پیدا شد: ID=", m_valleys[size].id, ", قیمت=", lowBuffer[0], ", زمان=", TimeToString(times[0]));
            break;
         }
      }
   }

   //--- ایجاد لیبل وضعیت
   if(!ObjectCreate(0, statusLabelName, OBJ_LABEL, 0, 0, 0))
   {
      if(EnableLogging) Print("خطا: لیبل وضعیت ایجاد نشد!");
      return false;
   }
   ObjectSetInteger(0, statusLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, statusLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, statusLabelName, OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(0, statusLabelName, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, statusLabelName, OBJPROP_FONT, FontName);
   ObjectSetInteger(0, statusLabelName, OBJPROP_COLOR, clrWhite);
   if(EnableLogging) Print("لیبل وضعیت با موفقیت ایجاد شد.");

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
      if(EnableLogging) Print("کندل جدید تشخیص داده شد: زمان=", TimeToString(currentTime));
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
   if(m_lastBrokenStructure.price == 0)
   {
      if(EnableLogging) Print("خطا: ساختار شکسته‌شده وجود ندارد!");
      return false;
   }

   bool isCeiling = m_lastBrokenStructure.id[0] == 'C';
   double anchorPrice = 0;
   datetime anchorTime = 0;
   double anchorHigh = 0;
   double anchorLow = 0;
   int startShift = iBarShift(_Symbol, TF, m_lastBrokenStructure.breakTime);
   int endShift = iBarShift(_Symbol, TF, m_lastBrokenStructure.time);
   
   if(EnableLogging) Print("جستجوی لنگرگاه: startShift=", startShift, ", endShift=", endShift, ", isCeiling=", isCeiling);
   
   for(int j = startShift; j < endShift; j++) // از شکست تا سقف/کف
   {
      double currentPrice = isCeiling ? iLow(_Symbol, TF, j) : iHigh(_Symbol, TF, j);
      datetime currentTime = iTime(_Symbol, TF, j);
      if(currentTime <= m_lastBrokenStructure.time)
      {
         if(EnableLogging) Print("کندل با زمان=", TimeToString(currentTime), " نادیده گرفته شد (قدیمی‌تر یا برابر با سقف/کف)");
         continue; // لنگرگاه باید جدیدتر از سقف/کف باشه
      }
      if(anchorPrice == 0 || (isCeiling && currentPrice < anchorPrice) || (!isCeiling && currentPrice > anchorPrice))
      {
         anchorPrice = currentPrice;
         anchorTime = currentTime;
         anchorHigh = iHigh(_Symbol, TF, j);
         anchorLow = iLow(_Symbol, TF, j);
      }
   }
   
   if(anchorPrice > 0 && anchorTime > m_lastBrokenStructure.time)
   {
      m_anchorPoint.price = anchorPrice;
      m_anchorPoint.time = anchorTime;
      m_anchorPoint.id = m_lastBrokenStructure.id + "_Anchor";
      m_anchorPoint.breakTime = 0;
      DrawGraphics("anchor", anchorPrice, anchorTime, m_lastBrokenStructure.id + "_Anchor", isCeiling, anchorHigh, anchorLow);
      if(EnableLogging) Print("لنگرگاه شناسایی شد: ID=", m_anchorPoint.id, ", قیمت=", anchorPrice, ", زمان=", TimeToString(anchorTime));
      return true;
   }
   
   if(EnableLogging) Print("خطا: لنگرگاه معتبر پیدا نشد (زمان لنگرگاه باید جدیدتر از سقف/کف باشد)");
   return false;
}

//+------------------------------------------------------------------+
//| نقشه‌بردار برای شناسایی ساختارها                              |
//+------------------------------------------------------------------+
void CSimpleFibonacciEngine::ScoutForStructure()
{
   if(!IsNewCandle()) return;

   if(EnableLogging) Print("شروع اسکن برای ساختارهای جدید...");

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
            if(EnableLogging) Print("سقف جدید: ID=", m_ceilings[size].id, ", قیمت=", highBuffer[0], ", زمان=", TimeToString(times[0]));
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
            if(EnableLogging) Print("کف جدید: ID=", m_valleys[size].id, ", قیمت=", lowBuffer[0], ", زمان=", TimeToString(times[0]));
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
            if(EnableLogging) Print("شکست سقف: ID=", m_ceilings[j].id, ", قیمت=", m_ceilings[j].price, ", زمان=", TimeToString(currentTime));
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
            if(EnableLogging) Print("شکست کف: ID=", m_valleys[j].id, ", قیمت=", m_valleys[j].price, ", زمان=", TimeToString(currentTime));
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
            if(EnableLogging) Print("شکست در انتظار تأیید سقف: ID=", m_ceilings[j].id);
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
            if(EnableLogging) Print("شکست در انتظار تأیید کف: ID=", m_valleys[j].id);
         }
      }
      for(int j = ArraySize(pendingBreaks) - 1; j >= 0; j--)
      {
         if(pendingBreaks[j].breakTime > 0 && currentTime >= pendingBreaks[j].breakTime)
         {
            if(pendingBreaks[j].id[0] == 'C') // سقف
            {
               for(int k = 0; k < ArraySize(m_ceilings); k++)
               {
                  if(m_ceilings[k].id == pendingBreaks[j].id)
                  {
                     m_ceilings[k].breakTime = currentTime;
                     if(EnableLogging) Print("شکست تأیید شده سقف: ID=", m_ceilings[k].id, ", زمان=", TimeToString(currentTime));
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
                     if(EnableLogging) Print("شکست تأیید شده کف: ID=", m_valleys[k].id, ", زمان=", TimeToString(currentTime));
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
      if(EnableLogging) Print("آخرین ساختار شکسته‌شده: ID=", m_lastBrokenStructure.id, ", قیمت=", m_lastBrokenStructure.price, ", زمان شکست=", TimeToString(m_lastBrokenStructure.breakTime));

      for(int j = ArraySize(m_ceilings) - 1; j >= 0; j--)
      {
         if(m_ceilings[j].id == dominantStructure.id)
         {
            ArrayRemove(m_ceilings, j, 1);
            if(EnableLogging) Print("سقف شکسته‌شده از آرایه حذف شد: ID=", dominantStructure.id);
            break;
         }
      }
      for(int j = ArraySize(m_valleys) - 1; j >= 0; j--)
      {
         if(m_valleys[j].id == dominantStructure.id)
         {
            ArrayRemove(m_valleys, j, 1);
            if(EnableLogging) Print("کف شکسته‌شده از آرایه حذف شد: ID=", dominantStructure.id);
            break;
         }
      }

      ClearOldGraphics(m_lastBrokenStructure.time);
      ResetAnalysis();

      bool isCeiling = m_lastBrokenStructure.id[0] == 'C';
      DrawGraphics("structure", m_lastBrokenStructure.price, m_lastBrokenStructure.time, m_lastBrokenStructure.id, isCeiling);
      datetime bosTime = (BreakType == BREAK_SIMPLE) ? m_lastBrokenStructure.breakTime : currentTime;
      DrawGraphics("bos", iClose(_Symbol, _Period, iBarShift(_Symbol, _Period, bosTime)), bosTime, m_lastBrokenStructure.id + "_BOS", isCeiling);

      //--- شناسایی و رسم لنگرگاه
      if(IdentifyAnchorPoint())
      {
         currentStatus = STATUS_ANALYSIS_IN_PROGRESS;
         ActivateFiboType2();
      }
      else
      {
         currentStatus = STATUS_WAITING;
         if(EnableLogging) Print("تحلیل متوقف شد: لنگرگاه معتبر پیدا نشد.");
      }
      DrawStatusLabel();
   }
}

//+------------------------------------------------------------------+
//| تحلیل و رسم فیبوناچی                                          |
//+------------------------------------------------------------------+
bool CSimpleFibonacciEngine::AnalyzeAndDrawFibo(bool isCeilingBreak)
{
   if(m_lastBrokenStructure.price == 0 || m_anchorPoint.price == 0)
   {
      if(EnableLogging) Print("خطا: ساختار شکسته‌شده یا لنگرگاه وجود ندارد!");
      return false;
   }

   bool isCeiling = m_lastBrokenStructure.id[0] == 'C';
   if(isCeiling != isCeilingBreak)
   {
      if(EnableLogging) Print("خطا: نوع شکست با ساختار بازار هماهنگ نیست!");
      return false;
   }

   //--- ورود به حالت تمرکز
   currentStatus = STATUS_ANALYSIS_IN_PROGRESS;
   DrawStatusLabel();
   ActivateFiboType2();
   return true;
}

//+------------------------------------------------------------------+
//| فعال‌سازی فیبوناچی نوع دوم                                    |
//+------------------------------------------------------------------+
void CSimpleFibonacciEngine::ActivateFiboType2()
{
   bool isCeiling = m_lastBrokenStructure.id[0] == 'C';
   double fiboZero = isCeiling ? iLow(_Symbol, TF, iBarShift(_Symbol, TF, m_anchorPoint.time)) : 
                                 iHigh(_Symbol, TF, iBarShift(_Symbol, TF, m_anchorPoint.time));
   double fiboHundred = m_lastBrokenStructure.price;
   string fiboId = "Fibo_Type2_Temp_" + TimeToString(m_lastBrokenStructure.breakTime);

   if(currentFibo.fiboId != "")
   {
      ObjectDelete(0, currentFibo.fiboId);
      ObjectDelete(0, currentFibo.fiboId + "_EntryZone");
      if(EnableLogging) Print("فیبوناچی قبلی حذف شد: ID=", currentFibo.fiboId);
   }

   if(ObjectCreate(0, fiboId, OBJ_FIBO, 0, m_anchorPoint.time, fiboZero, m_lastBrokenStructure.time, fiboHundred))
   {
      ObjectSetInteger(0, fiboId, OBJPROP_LEVELS, 8);
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 0, 0.0);
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 1, 1.0);
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 2, FiboEntryZoneMin / 100.0);
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 3, FiboEntryZoneMax / 100.0);
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 4, 1.5); // 150%
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 5, 2.0); // 200%
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 6, 2.5); // 250%
      ObjectSetDouble(0, fiboId, OBJPROP_LEVELVALUE, 7, -0.5);
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
      currentFibo.isCeilingBreak = isCeiling;
      currentFibo.fiboId = fiboId;
      currentFibo.isTemporary = true;
      currentStatus = STATUS_FIBO_TYPE2_TEMP;
      DrawStatusLabel();
      if(EnableLogging) Print("فیبوناچی نوع دوم موقت رسم شد: ID=", fiboId, ", صفر=", fiboZero, ", صد=", fiboHundred);
   }
   else
   {
      if(EnableLogging) Print("خطا: فیبوناچی موقت رسم نشد!");
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
   if(EnableLogging) Print("بررسی شرایط: High=", highPrice, ", Low=", lowPrice, ", Status=", EnumToString(currentStatus));

   //--- چک کردن حرمت لنگرگاه
   if(currentFibo.isCeilingBreak && lowPrice < currentFibo.zeroLevel)
   {
      if(EnableLogging) Print("تحلیل باطل شد: قیمت زیر لنگرگاه رفت (قیمت=", lowPrice, ", لنگرگاه=", currentFibo.zeroLevel, ")");
      ResetAnalysis();
      return;
   }
   if(!currentFibo.isCeilingBreak && highPrice > currentFibo.zeroLevel)
   {
      if(EnableLogging) Print("تحلیل باطل شد: قیمت بالای لنگرگاه رفت (قیمت=", highPrice, ", لنگرگاه=", currentFibo.zeroLevel, ")");
      ResetAnalysis();
      return;
   }

   //--- چک کردن ناحیه ورود
   if(currentStatus == STATUS_FIBO_TYPE2_ACTIVE && CheckEntryZone(currentFibo.zeroLevel, currentFibo.hundredLevel, FiboEntryZoneMin, FiboEntryZoneMax))
   {
      currentStatus = STATUS_IN_ENTRY_ZONE;
      DrawStatusLabel();
      if(EnableLogging) Print("قیمت وارد ناحیه ورود شد: Min=", currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMin / 100.0), 
                             ", Max=", currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMax / 100.0));
   }
   else if(currentStatus == STATUS_IN_ENTRY_ZONE && !CheckEntryZone(currentFibo.zeroLevel, currentFibo.hundredLevel, FiboEntryZoneMin, FiboEntryZoneMax))
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
   double level150 = currentFibo.isCeilingBreak ? 
                     currentFibo.hundredLevel + (currentFibo.zeroLevel - currentFibo.hundredLevel) * 1.5 : 
                     currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * 1.5;
   double level200 = currentFibo.isCeilingBreak ? 
                     currentFibo.hundredLevel + (currentFibo.zeroLevel - currentFibo.hundredLevel) * 2.0 : 
                     currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * 2.0;
   double level250 = currentFibo.isCeilingBreak ? 
                     currentFibo.hundredLevel + (currentFibo.zeroLevel - currentFibo.hundredLevel) * 2.5 : 
                     currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * 2.5;

   if(EnableLogging) Print("چک کردن سطوح فیبو: 150%=", level150, ", 200%=", level200, ", 250%=", level250, ", High=", highPrice, ", Low=", lowPrice);

   //--- باطل شدن اگر قیمت از 200% رد بشه
   if((currentFibo.isCeilingBreak && highPrice > level200) || (!currentFibo.isCeilingBreak && lowPrice < level200))
   {
      if(EnableLogging) Print("تحلیل باطل شد: قیمت از سطح 200% عبور کرد (قیمت=", currentFibo.isCeilingBreak ? highPrice : lowPrice, ", سطح 200%=", level200, ")");
      ResetAnalysis();
      return;
   }

   //--- تشخیص واکنش در 150% یا 200%
   static bool reached150 = false;
   static bool reached200 = false;
   static datetime reactionTime = 0;
   static double reactionLevel = 0;

   if(currentStatus == STATUS_FIBO_TYPE2_TEMP)
   {
      if((currentFibo.isCeilingBreak && highPrice >= level150 && highPrice <= level200) || 
         (!currentFibo.isCeilingBreak && lowPrice <= level150 && lowPrice >= level200))
      {
         reached150 = true;
         if(EnableLogging) Print("قیمت به سطح 150% رسید: قیمت=", currentFibo.isCeilingBreak ? highPrice : lowPrice, ", سطح 150%=", level150);
      }
      if((currentFibo.isCeilingBreak && highPrice >= level200) || 
         (!currentFibo.isCeilingBreak && lowPrice <= level200))
      {
         reached200 = true;
         if(EnableLogging) Print("قیمت به سطح 200% رسید: قیمت=", currentFibo.isCeilingBreak ? highPrice : lowPrice, ", سطح 200%=", level200);
      }

      //--- چک کردن اصلاح (واکنش) به سمت ناحیه ورود
      double entryZoneMin = currentFibo.isCeilingBreak ? 
                           currentFibo.hundredLevel + (currentFibo.zeroLevel - currentFibo.hundredLevel) * (FiboEntryZoneMin / 100.0) : 
                           currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMin / 100.0);
      double entryZoneMax = currentFibo.isCeilingBreak ? 
                           currentFibo.hundredLevel + (currentFibo.zeroLevel - currentFibo.hundredLevel) * (FiboEntryZoneMax / 100.0) : 
                           currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMax / 100.0);

      if(reached150 && !reached200 && 
         ((currentFibo.isCeilingBreak && lowPrice <= entryZoneMax) || 
          (!currentFibo.isCeilingBreak && highPrice >= entryZoneMin)))
      {
         reactionLevel = level150;
         reactionTime = iTime(_Symbol, _Period, 1);
         if(EnableLogging) Print("واکنش در سطح 150% تشخیص داده شد: قیمت=", currentFibo.isCeilingBreak ? lowPrice : highPrice, ", ناحیه ورود=", entryZoneMin, " تا ", entryZoneMax);
      }
      else if(reached200 && 
              ((currentFibo.isCeilingBreak && lowPrice <= entryZoneMax) || 
               (!currentFibo.isCeilingBreak && highPrice >= entryZoneMin)))
      {
         reactionLevel = level200;
         reactionTime = iTime(_Symbol, _Period, 1);
         if(EnableLogging) Print("واکنش در سطح 200% تشخیص داده شد: قیمت=", currentFibo.isCeilingBreak ? lowPrice : highPrice, ", ناحیه ورود=", entryZoneMin, " تا ", entryZoneMax);
      }

      if(reactionLevel > 0)
      {
         ObjectDelete(0, currentFibo.fiboId);
         ObjectDelete(0, currentFibo.fiboId + "_EntryZone");
         if(EnableLogging) Print("فیبو موقت حذف شد: ID=", currentFibo.fiboId);

         currentFibo.hundredLevel = reactionLevel;
         currentFibo.hundredTime = reactionTime;
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
            ObjectSetInteger(0, fiboId, OBJPROP_COLOR, currentFibo.isCeilingBreak ? FiboType2ColorDown : FiboType2ColorUp);
            ObjectSetInteger(0, fiboId, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, fiboId, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, fiboId, OBJPROP_RAY_RIGHT, true);

            double entryZoneMin = currentFibo.isCeilingBreak ? 
                                 currentFibo.hundredLevel + (currentFibo.zeroLevel - currentFibo.hundredLevel) * (FiboEntryZoneMin / 100.0) : 
                                 currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMin / 100.0);
            double entryZoneMax = currentFibo.isCeilingBreak ? 
                                 currentFibo.hundredLevel + (currentFibo.zeroLevel - currentFibo.hundredLevel) * (FiboEntryZoneMax / 100.0) : 
                                 currentFibo.zeroLevel + (currentFibo.hundredLevel - currentFibo.zeroLevel) * (FiboEntryZoneMax / 100.0);
            string entryZoneId = fiboId + "_EntryZone";
            ObjectCreate(0, entryZoneId, OBJ_RECTANGLE, 0, currentFibo.zeroTime, entryZoneMin, currentFibo.hundredTime, entryZoneMax);
            ObjectSetInteger(0, entryZoneId, OBJPROP_COLOR, EntryZoneColor);
            ObjectSetInteger(0, entryZoneId, OBJPROP_BACK, true);
            ObjectSetInteger(0, entryZoneId, OBJPROP_FILL, true);

            currentFibo.fiboId = fiboId;
            currentFibo.isTemporary = false;
            currentStatus = STATUS_FIBO_TYPE2_ACTIVE;
            DrawStatusLabel();
            if(EnableLogging) Print("فیبوناچی اصلی رسم شد: ID=", fiboId, ", صفر=", currentFibo.zeroLevel, ", صد=", currentFibo.hundredLevel);
         }
         else
         {
            if(EnableLogging) Print("خطا: فیبوناچی اصلی رسم نشد!");
         }

         reached150 = false;
         reached200 = false;
         reactionLevel = 0;
         reactionTime = 0;
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
         if(EnableLogging) Print("گرافیک ساختار رسم شد: ID=", objName, ", قیمت=", price, ", زمان=", TimeToString(time));
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
         if(EnableLogging) Print("گرافیک BOS رسم شد: ID=", objName, ", قیمت=", price, ", زمان=", TimeToString(time));
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
         if(EnableLogging) Print("گرافیک لنگرگاه رسم شد: ID=", objName, ", قیمت High=", highPrice, ", Low=", lowPrice, ", زمان=", TimeToString(time));
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
   if(EnableLogging) Print("لیبل وضعیت به‌روزرسانی شد: ", statusText);
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
         {
            ObjectDelete(0, name);
            if(EnableLogging) Print("گرافیک قدیمی حذف شد: ID=", name);
         }
      }
   }
   if(currentFibo.fiboId != "")
   {
      ObjectDelete(0, currentFibo.fiboId);
      ObjectDelete(0, currentFibo.fiboId + "_EntryZone");
      if(EnableLogging) Print("فیبوناچی و ناحیه ورود حذف شدند: ID=", currentFibo.fiboId);
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
   double entryZoneMin = currentFibo.isCeilingBreak ? 
                        hundredLevel + (zeroLevel - hundredLevel) * (minPercent / 100.0) : 
                        zeroLevel + (hundredLevel - zeroLevel) * (minPercent / 100.0);
   double entryZoneMax = currentFibo.isCeilingBreak ? 
                        hundredLevel + (zeroLevel - hundredLevel) * (maxPercent / 100.0) : 
                        zeroLevel + (hundredLevel - zeroLevel) * (maxPercent / 100.0);
   bool inZone = (highPrice >= entryZoneMin && lowPrice <= entryZoneMax);
   if(EnableLogging) Print("چک ناحیه ورود: Min=", entryZoneMin, ", Max=", entryZoneMax, ", High=", highPrice, ", Low=", lowPrice, ", در ناحیه=", inZone);
   return inZone;
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
      if(EnableLogging) Print("فیبوناچی و ناحیه ورود حذف شدند: ID=", currentFibo.fiboId);
   }
   currentFibo.zeroLevel = 0;
   currentFibo.hundredLevel = 0;
   currentFibo.zeroTime = 0;
   currentFibo.hundredTime = 0;
   currentFibo.isCeilingBreak = true;
   currentFibo.fiboId = "";
   currentFibo.isTemporary = false;
   currentStatus = STATUS_WAITING;
   DrawStatusLabel();
   if(EnableLogging) Print("تحلیل بازنشانی شد");
}
