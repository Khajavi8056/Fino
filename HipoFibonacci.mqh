//+------------------------------------------------------------------+
//| HipoFibonacci.mqh                                                |
//| Copyright © 2025 HipoAlgorithm                                   |
//| https://hipoalgorithm.com                                        |
//| نسخه: 1.3                                                        |
//| توضیحات: این فایل شامل کلاس CHipoFibonacci است که برای شناسایی نقاط چرخش بازار، رسم سطوح فیبوناچی و مدیریت استراتژی‌های معاملاتی در متاتریدر 5 طراحی شده است. |
//+------------------------------------------------------------------+

#property copyright "HipoAlgorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.3"
#property strict

//+------------------------------------------------------------------+
//| تعریف انوم‌ها (Enums)                                            |
//| این بخش شامل انوم‌هایی است که برای دسته‌بندی نوع سیگنال‌ها، وضعیت‌ها، نوع فیبوناچی و روش‌های تشخیص استفاده می‌شوند. |
//+------------------------------------------------------------------+

enum E_SignalType {
   SIGNAL_BUY,          // سیگنال خرید
   SIGNAL_SELL,         // سیگنال فروش
   STOP_SEARCH          // توقف جستجو
};

enum E_Status {
   WAITING_FOR_COMMAND,            // منتظر دریافت دستور
   SEARCHING_FOR_ANCHOR_LOW,       // جستجوی نقطه پایین لنگرگاه
   SEARCHING_FOR_ANCHOR_HIGH,      // جستجوی نقطه بالای لنگرگاه
   MONITORING_SCENARIO_1_PROGRESS, // پایش پیشرفت سناریو 1
   SCENARIO_1_AWAITING_PULLBACK,   // سناریو 1 - انتظار برای پولبک
   SCENARIO_1_AWAITING_BREAKOUT,   // سناریو 1 - انتظار برای شکست
   SCENARIO_1_CONFIRMED_AWAITING_ENTRY, // سناریو 1 - انتظار برای ورود تأیید شده
   SCENARIO_2_ACTIVE_TARGETING_EXTENSION, // پایش سناریو 2 و هدف‌گذاری اکستنشن
   SCENARIO_2_CONFIRMED_AWAITING_ENTRY,  // سناریو 2 - انتظار برای ورود تأیید شده
   ENTRY_ZONE_ACTIVE                 // ناحیه ورود فعال
};

enum E_FiboType {
   FIBO_MOTHER,        // سطح فیبوناچی مادر
   FIBO_INTERMEDIATE,  // سطح فیبوناچی میانی
   FIBO_FINAL          // سطح فیبوناچی نهایی
};

enum E_DetectionMethod {
   METHOD_SIMPLE,                // روش ساده
   METHOD_SEQUENTIAL,            // روش ترتیبی
   METHOD_POWER_SWING,           // روش نوسان قدرتی
   METHOD_ZIGZAG,                // روش زیگزاگ
   METHOD_BREAK_OF_STRUCTURE,    // روش شکست ساختار
   METHOD_MARKET_STRUCTURE_SHIFT // روش تغییر ساختار بازار
};

enum E_SequentialCriterion {
   CRITERION_HIGH,  // معیار بالا
   CRITERION_LOW,   // معیار پایین
   CRITERION_OPEN,  // معیار باز
   CRITERION_CLOSE  // معیار بسته
};

//+------------------------------------------------------------------+
//| تعریف ساختارها (Structures)                                       |
//| این بخش شامل ساختارهایی برای ذخیره تنظیمات و نقاط چرخش است.       |
//+------------------------------------------------------------------+

struct PeakValley {
   double price;    // قیمت نقطه
   datetime time;   // زمان نقطه
   int position;    // موقعیت در آرایه
};

struct HipoSettings {
   ENUM_TIMEFRAMES CalculationTimeframe; // تایم‌فریم محاسبات
   bool Enable_Drawing;                  // فعال‌سازی رسم
   bool Enable_Logging;                  // فعال‌سازی لاگ
   bool Enable_Status_Panel;             // فعال‌سازی پنل وضعیت
   int MaxCandles;                       // حداکثر تعداد کندل‌ها
   double MarginPips;                    // حاشیه به پیپ

   bool EnforceStrictSequence;           // اجبار به ترتیب دقیق
   E_DetectionMethod DetectionMethod;    // روش تشخیص
   int Lookback;                         // بازه نگاه به عقب
   int SequentialLookback;               // بازه نگاه به عقب ترتیبی
   bool UseStrictSequential;             // استفاده از ترتیب دقیق
   E_SequentialCriterion SequentialCriterion; // معیار ترتیبی
   int AtrPeriod;                        // دوره ATR
   double AtrMultiplier;                 // ضریب ATR
   int ZigZagDepth;                      // عمق زیگزاگ
   double ZigZagDeviation;               // انحراف زیgzاگ

   double EntryZone_LowerLevel;          // سطح پایین ناحیه ورود
   double EntryZone_UpperLevel;          // سطح بالا ناحیه ورود
   double ExtensionZone_LowerLevel;      // سطح پایین ناحیه اکستنشن
   double ExtensionZone_UpperLevel;      // سطح بالا ناحیه اکستنشن
   double FibonacciLevels[10];           // سطوح فیبوناچی
   int FibonacciLevelsCount;             // تعداد سطوح فیبوناچی

   color MotherFibo_Color;               // رنگ فیبوناچی مادر
   color IntermediateFibo_Color;         // رنگ فیبوناچی میانی
   color BuyEntryFibo_Color;             // رنگ ناحیه ورود خرید
   color SellEntryFibo_Color;            // رنگ ناحیه ورود فروش
};

//+------------------------------------------------------------------+
//| کلاس CHipoFibonacci                                              |
//| این کلاس اصلی برای مدیریت منطق تشخیص نقاط و رسم سطوح است.        |
//+------------------------------------------------------------------+

class CHipoFibonacci {
private:
   HipoSettings settings;
   E_SignalType signalType;
   E_Status currentStatus;
   datetime anchorID;
   PeakValley anchor;
   PeakValley mother;
   PeakValley temporary;
   PeakValley finalPoint;
   datetime entryZoneActivationTime;
   string finalFiboScenario;
   bool isEntryZoneActive;
   int handleATR;
   double atrBuffer[];
   double swingHighs_Array[2];
   double swingLows_Array[2];
   datetime swingHighs_Time[2];
   datetime swingLows_Time[2];
   PeakValley lastConfirmedPeak;
   PeakValley lastConfirmedValley;
   PeakValley candidatePeak;
   PeakValley candidateValley;
   bool isPullbackStarted;

   double high[];
   double low[];
   double open[];
   double close[];
   datetime time[];
   int rates_total;

   bool FindValley(datetime &localTime, double &localPrice, int &localPosition); // یافتن دره
   bool FindPeak(datetime &localTime, double &localPrice, int &localPosition);  // یافتن قله
   bool IsSequential(int i, bool isPeak);                                      // بررسی ترتیب
   bool CheckSequential(int i, bool isPeak, const double &values[]);           // بررسی ترتیبی
   bool HasEnoughPower(int i, bool isPeak, double price, datetime localTime);  // بررسی قدرت
   bool IsZigZag(int i, bool isPeak);                                         // بررسی زیgzاگ
   void IdentifySwingPoints(int i, bool &isSwingHigh, bool &isSwingLow);       // شناسایی نقاط چرخش
   void IdentifyMSS(int i, bool &isFinalPeak, bool &isFinalValley);            // شناسایی تغییر ساختار
   void UpdateSwingArray(double &array[], datetime &timeArray[], double price, datetime localTime); // به‌روزرسانی آرایه نقاط

   void CreateStatusPanel();          // ایجاد پنل وضعیت
   void UpdateStatusPanel();          // به‌روزرسانی پنل وضعیت
   void DrawFibo(E_FiboType type, double price1, double price2, datetime time1, datetime time2, color clr, string scenario = ""); // رسم فیبوناچی
   void DeleteFiboObjects();          // حذف اشیاء فیبوناچی
   double CalculateFiboLevelPrice(E_FiboType type, double level); // محاسبه قیمت سطح فیبوناچی
   void ProcessBuyLogic();            // پردازش منطق خرید
   void ProcessSellLogic();           // پردازش منطق فروش

public:
   CHipoFibonacci();                  // سازنده
   ~CHipoFibonacci();                 // نابودگر

   void Init(HipoSettings &inputSettings); // تنظیم اولیه
   void ReceiveCommand(E_SignalType type, ENUM_TIMEFRAMES timeframe); // دریافت دستور
   void OnNewCandle(const int rates_total_input, const datetime &time_input[], const double &open_input[], const double &high_input[], const double &low_input[], const double &close_input[]); // پردازش کندل جدید
   bool IsEntryZoneActive() { return isEntryZoneActive; } // بررسی فعال بودن ناحیه ورود
   datetime GetEntryZoneActivationTime() { return entryZoneActivationTime; } // دریافت زمان فعال‌سازی ناحیه ورود
   string GetFinalFiboScenario() { return finalFiboScenario; } // دریافت سناریوی نهایی
   E_Status GetCurrentStatus() { return currentStatus; } // دریافت وضعیت فعلی
   double GetFiboLevelPrice(E_FiboType type, double level) { return CalculateFiboLevelPrice(type, level); } // دریافت قیمت سطح فیبوناچی
};

//+------------------------------------------------------------------+
//| سازنده (Constructor)                                             |
//| این تابع برای راه‌اندازی اولیه شیء استفاده می‌شود.               |
//+------------------------------------------------------------------+

CHipoFibonacci::CHipoFibonacci() {
   signalType = STOP_SEARCH;
   currentStatus = WAITING_FOR_COMMAND;
   anchorID = 0;
   anchor.price = 0;
   anchor.time = 0;
   anchor.position = 0;
   mother.price = 0;
   mother.time = 0;
   mother.position = 0;
   temporary.price = 0;
   temporary.time = 0;
   temporary.position = 0;
   finalPoint.price = 0;
   finalPoint.time = 0;
   finalPoint.position = 0;
   entryZoneActivationTime = 0;
   finalFiboScenario = "";
   isEntryZoneActive = false;
   handleATR = INVALID_HANDLE;
   lastConfirmedPeak.price = 0;
   lastConfirmedValley.price = 0;
   candidatePeak.price = 0;
   candidateValley.price = 0;
   isPullbackStarted = false;
   ArrayInitialize(swingHighs_Array, 0);
   ArrayInitialize(swingLows_Array, 0);
   ArrayInitialize(swingHighs_Time, 0);
   ArrayInitialize(swingLows_Time, 0);
}

//+------------------------------------------------------------------+
//| نابودگر (Destructor)                                             |
//| این تابع برای آزادسازی منابع هنگام نابودی شیء استفاده می‌شود.    |
//+------------------------------------------------------------------+

CHipoFibonacci::~CHipoFibonacci() {
   if(handleATR != INVALID_HANDLE) IndicatorRelease(handleATR);
   DeleteFiboObjects();
   ObjectDelete(0, "HipoFibonacci_Panel");
}

//+------------------------------------------------------------------+
//| تنظیم اولیه (Initialization)                                     |
//| این تابع تنظیمات اولیه را بر اساس ورودی‌ها اعمال می‌کند.         |
//+------------------------------------------------------------------+

void CHipoFibonacci::Init(HipoSettings &inputSettings) {
   settings.CalculationTimeframe = inputSettings.CalculationTimeframe == 0 ? PERIOD_CURRENT : inputSettings.CalculationTimeframe;
   settings.Enable_Drawing = inputSettings.Enable_Drawing;
   settings.Enable_Logging = inputSettings.Enable_Logging;
   settings.Enable_Status_Panel = inputSettings.Enable_Status_Panel;
   settings.MaxCandles = inputSettings.MaxCandles > 0 ? inputSettings.MaxCandles : 500;
   settings.MarginPips = inputSettings.MarginPips > 0 ? inputSettings.MarginPips : 1.0;

   settings.EnforceStrictSequence = inputSettings.EnforceStrictSequence;
   settings.DetectionMethod = inputSettings.DetectionMethod;
   settings.Lookback = inputSettings.Lookback > 0 ? inputSettings.Lookback : 3;
   settings.SequentialLookback = inputSettings.SequentialLookback > 0 ? inputSettings.SequentialLookback : 2;
   settings.UseStrictSequential = inputSettings.UseStrictSequential;
   settings.SequentialCriterion = inputSettings.SequentialCriterion;
   settings.AtrPeriod = inputSettings.AtrPeriod > 0 ? inputSettings.AtrPeriod : 14;
   settings.AtrMultiplier = inputSettings.AtrMultiplier > 0 ? inputSettings.AtrMultiplier : 2.5;
   settings.ZigZagDepth = inputSettings.ZigZagDepth > 0 ? inputSettings.ZigZagDepth : 12;
   settings.ZigZagDeviation = inputSettings.ZigZagDeviation > 0 ? inputSettings.ZigZagDeviation : 5.0;

   settings.EntryZone_LowerLevel = inputSettings.EntryZone_LowerLevel > 0 ? inputSettings.EntryZone_LowerLevel : 50.0;
   settings.EntryZone_UpperLevel = inputSettings.EntryZone_UpperLevel > settings.EntryZone_LowerLevel ? inputSettings.EntryZone_UpperLevel : 68.0;
   settings.ExtensionZone_LowerLevel = inputSettings.ExtensionZone_LowerLevel > 100 ? inputSettings.ExtensionZone_LowerLevel : 150.0;
   settings.ExtensionZone_UpperLevel = inputSettings.ExtensionZone_UpperLevel > settings.ExtensionZone_LowerLevel ? inputSettings.ExtensionZone_UpperLevel : 200.0;
   settings.FibonacciLevelsCount = inputSettings.FibonacciLevelsCount > 0 && inputSettings.FibonacciLevelsCount <= 10 ? inputSettings.FibonacciLevelsCount : 8;
   if(inputSettings.FibonacciLevelsCount == 0) {
      settings.FibonacciLevels[0] = 0.0;
      settings.FibonacciLevels[1] = 30.0;
      settings.FibonacciLevels[2] = 50.0;
      settings.FibonacciLevels[3] = 68.0;
      settings.FibonacciLevels[4] = 100.0;
      settings.FibonacciLevels[5] = 150.0;
      settings.FibonacciLevels[6] = 200.0;
      settings.FibonacciLevels[7] = 250.0;
   } else {
      ArrayCopy(settings.FibonacciLevels, inputSettings.FibonacciLevels, 0, 0, inputSettings.FibonacciLevelsCount);
   }

   settings.MotherFibo_Color = inputSettings.MotherFibo_Color == clrNONE ? clrGray : inputSettings.MotherFibo_Color;
   settings.IntermediateFibo_Color = inputSettings.IntermediateFibo_Color == clrNONE ? clrLemonChiffon : inputSettings.IntermediateFibo_Color;
   settings.BuyEntryFibo_Color = inputSettings.BuyEntryFibo_Color == clrNONE ? clrLightGreen : inputSettings.BuyEntryFibo_Color;
   settings.SellEntryFibo_Color = inputSettings.SellEntryFibo_Color == clrNONE ? clrRed : inputSettings.SellEntryFibo_Color;

   ArrayResize(atrBuffer, settings.MaxCandles);

   if(settings.DetectionMethod == METHOD_POWER_SWING) {
      handleATR = iATR(_Symbol, settings.CalculationTimeframe, settings.AtrPeriod);
      if(handleATR == INVALID_HANDLE && settings.Enable_Logging) Print("خطا در ایجاد هندل ATR");
   }

   if(settings.Enable_Status_Panel) CreateStatusPanel();
}

//+------------------------------------------------------------------+
//| دریافت دستور (Receive Command)                                   |
//| این تابع دستورهای خرید، فروش یا توقف را دریافت و پردازش می‌کند.  |
//+------------------------------------------------------------------+

void CHipoFibonacci::ReceiveCommand(E_SignalType type, ENUM_TIMEFRAMES timeframe) {
   if(type == STOP_SEARCH) {
      if(settings.Enable_Logging) Print("دریافت دستور توقف جستجو");
      DeleteFiboObjects();
      signalType = STOP_SEARCH;
      currentStatus = WAITING_FOR_COMMAND;
      anchorID = 0;
      anchor.price = 0;
      anchor.time = 0;
      anchor.position = 0;
      mother.price = 0;
      mother.time = 0;
      mother.position = 0;
      temporary.price = 0;
      temporary.time = 0;
      temporary.position = 0;
      finalPoint.price = 0;
      finalPoint.time = 0;
      finalPoint.position = 0;
      isEntryZoneActive = false;
      entryZoneActivationTime = 0;
      finalFiboScenario = "";
      isPullbackStarted = false;
      UpdateStatusPanel();
   } else {
      signalType = type;
      settings.CalculationTimeframe = timeframe == 0 ? PERIOD_CURRENT : timeframe;
      currentStatus = (type == SIGNAL_BUY) ? SEARCHING_FOR_ANCHOR_LOW : SEARCHING_FOR_ANCHOR_HIGH;
      anchorID = 0;
      anchor.price = 0;
      anchor.time = 0;
      anchor.position = 0;
      mother.price = 0;
      mother.time = 0;
      mother.position = 0;
      temporary.price = 0;
      temporary.time = 0;
      temporary.position = 0;
      finalPoint.price = 0;
      finalPoint.time = 0;
      finalPoint.position = 0;
      isEntryZoneActive = false;
      entryZoneActivationTime = 0;
      finalFiboScenario = "";
      isPullbackStarted = false;
      if(settings.Enable_Logging) Print("دریافت دستور ", EnumToString(type), " در تایم‌فریم ", EnumToString(timeframe));
      UpdateStatusPanel();
   }
}

//+------------------------------------------------------------------+
//| پردازش کندل جدید (On New Candle)                                 |
//| این تابع با دریافت داده‌های جدید کندل، منطق را به‌روزرسانی می‌کند. |
//+------------------------------------------------------------------+

void CHipoFibonacci::OnNewCandle(const int rates_total_input, const datetime &time_input[], const double &open_input[], const double &high_input[], const double &low_input[], const double &close_input[]) {
   if(currentStatus == WAITING_FOR_COMMAND) return;

   rates_total = rates_total_input;
   ArrayResize(high, rates_total);
   ArrayResize(low, rates_total);
   ArrayResize(open, rates_total);
   ArrayResize(close, rates_total);
   ArrayResize(time, rates_total);
   ArrayCopy(high, high_input, 0, 0, rates_total);
   ArrayCopy(low, low_input, 0, 0, rates_total);
   ArrayCopy(open, open_input, 0, 0, rates_total);
   ArrayCopy(close, close_input, 0, 0, rates_total);
   ArrayCopy(time, time_input, 0, 0, rates_total);

   if(settings.DetectionMethod == METHOD_POWER_SWING && handleATR != INVALID_HANDLE) {
      if(CopyBuffer(handleATR, 0, 0, MathMin(rates_total, settings.MaxCandles), atrBuffer) <= 0) {
         if(settings.Enable_Logging) Print("خطا در کپی مقادیر ATR");
         return;
      }
   }

   if(signalType == SIGNAL_BUY) ProcessBuyLogic();
   else if(signalType == SIGNAL_SELL) ProcessSellLogic();

   UpdateStatusPanel();
}

//+------------------------------------------------------------------+
//| پردازش منطق خرید (Process Buy Logic)                             |
//| این تابع منطق مربوط به استراتژی خرید را مدیریت می‌کند.           |
//+------------------------------------------------------------------+

void CHipoFibonacci::ProcessBuyLogic() {
   if(currentStatus == SEARCHING_FOR_ANCHOR_LOW) {
      datetime localTime;
      double localPrice;
      int localPosition;
      if(FindValley(localTime, localPrice, localPosition)) {
         anchor.price = localPrice;
         anchor.time = localTime;
         anchor.position = localPosition;
         anchorID = localTime;
         datetime peakTime;
         double peakPrice;
         int peakPosition;
         if(FindPeak(peakTime, peakPrice, peakPosition) && peakTime < localTime) {
            mother.price = peakPrice;
            mother.time = peakTime;
            mother.position = peakPosition;
            if(settings.Enable_Drawing) DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
            if(settings.Enable_Logging) Print("Anchor_Low یافت شد در قیمت ", localPrice, " در ", TimeToString(localTime), ", Mother_High در ", peakPrice);
            currentStatus = MONITORING_SCENARIO_1_PROGRESS;
         }
      } else {
         if(settings.Enable_Logging) Print("هیچ دره‌ای در ", settings.MaxCandles, " کندل یافت نشد");
      }
   }
   else if(currentStatus == MONITORING_SCENARIO_1_PROGRESS) {
      if(settings.Enable_Drawing) DrawFibo(FIBO_INTERMEDIATE, anchor.price, high[1], anchor.time, time[1], settings.IntermediateFibo_Color);
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      if(high[1] > mother.price) {
         currentStatus = SCENARIO_2_ACTIVE_TARGETING_EXTENSION;
         isPullbackStarted = false;
         finalPoint.price = 0;
         finalPoint.time = 0;
         finalPoint.position = 0;
         if(settings.Enable_Logging) Print("ورود به سناریو ۲: شکست Mother_High در ", high[1]);
         return;
      }
      if(high[1] > temporary.price) {
         temporary.price = high[1];
         temporary.time = time[1];
         temporary.position = 1;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh && temporary.price > 0) {
         currentStatus = SCENARIO_1_AWAITING_BREAKOUT;
         if(settings.Enable_Logging) Print("پولبک به ناحیه طلایی در قیمت ", close[1], "، انتظار شکست Temporary_High در ", temporary.price);
      }
   }
   else if(currentStatus == SCENARIO_1_AWAITING_BREAKOUT) {
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      if(high[1] > temporary.price) {
         if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, high[1], anchor.time, time[1], settings.BuyEntryFibo_Color, "Scenario1");
         finalPoint.price = high[1];
         finalPoint.time = time[1];
         finalPoint.position = 1;
         finalFiboScenario = "Scenario1";
         currentStatus = SCENARIO_1_CONFIRMED_AWAITING_ENTRY;
         if(settings.Enable_Logging) Print("سناریو ۱ تأیید شد، Temporary_High شکسته شد در ", high[1]);
      }
   }
   else if(currentStatus == SCENARIO_1_CONFIRMED_AWAITING_ENTRY) {
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], " در ", TimeToString(time[1]));
      }
   }
   else if(currentStatus == SCENARIO_2_ACTIVE_TARGETING_EXTENSION) {
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      if(high[1] > CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      double extensionLow = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_LowerLevel);
      double extensionHigh = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_UpperLevel);
      if(high[1] >= extensionLow) {
         if(high[1] > finalPoint.price) {
            finalPoint.price = high[1];
            finalPoint.time = time[1];
            finalPoint.position = 1;
            if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.IntermediateFibo_Color, "Scenario2");
            if(settings.Enable_Logging && finalPoint.price > 0) Print("آپدیت سقف نهایی سناریو ۲ در قیمت ", finalPoint.price, " در ", TimeToString(finalPoint.time));
         }
         if(high[1] < finalPoint.price && finalPoint.price > 0) {
            isPullbackStarted = true;
            if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.BuyEntryFibo_Color, "Scenario2");
            finalFiboScenario = "Scenario2";
            currentStatus = SCENARIO_2_CONFIRMED_AWAITING_ENTRY;
            if(settings.Enable_Logging) Print("سناریو ۲ تأیید شد، پولبک از سقف نهایی ", finalPoint.price, " شروع شد");
         }
      }
   }
   else if(currentStatus == SCENARIO_2_CONFIRMED_AWAITING_ENTRY) {
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      if(high[1] > CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], " در ", TimeToString(time[1]));
      }
   }
   else if(currentStatus == ENTRY_ZONE_ACTIVE) {
   }
}

//+------------------------------------------------------------------+
//| پردازش منطق فروش (Process Sell Logic)                            |
//| این تابع منطق مربوط به استراتژی فروش را مدیریت می‌کند.           |
//+------------------------------------------------------------------+

void CHipoFibonacci::ProcessSellLogic() {
   if(currentStatus == SEARCHING_FOR_ANCHOR_HIGH) {
      datetime localTime;
      double localPrice;
      int localPosition;
      if(FindPeak(localTime, localPrice, localPosition)) {
         anchor.price = localPrice;
         anchor.time = localTime;
         anchor.position = localPosition;
         anchorID = localTime;
         datetime valleyTime;
         double valleyPrice;
         int valleyPosition;
         if(FindValley(valleyTime, valleyPrice, valleyPosition) && valleyTime < localTime) {
            mother.price = valleyPrice;
            mother.time = valleyTime;
            mother.position = valleyPosition;
            if(settings.Enable_Drawing) DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
            if(settings.Enable_Logging) Print("Anchor_High یافت شد در قیمت ", localPrice, " در ", TimeToString(localTime), ", Mother_Low در ", valleyPrice);
            currentStatus = MONITORING_SCENARIO_1_PROGRESS;
         }
      } else {
         if(settings.Enable_Logging) Print("هیچ قله‌ای در ", settings.MaxCandles, " کندل یافت نشد");
      }
   }
   else if(currentStatus == MONITORING_SCENARIO_1_PROGRESS) {
      if(settings.Enable_Drawing) DrawFibo(FIBO_INTERMEDIATE, anchor.price, low[1], anchor.time, time[1], settings.IntermediateFibo_Color);
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      if(low[1] < mother.price) {
         currentStatus = SCENARIO_2_ACTIVE_TARGETING_EXTENSION;
         isPullbackStarted = false;
         finalPoint.price = 0;
         finalPoint.time = 0;
         finalPoint.position = 0;
         if(settings.Enable_Logging) Print("ورود به سناریو ۲: شکست Mother_Low در ", low[1]);
         return;
      }
      if(low[1] < temporary.price || temporary.price == 0) {
         temporary.price = low[1];
         temporary.time = time[1];
         temporary.position = 1;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh && temporary.price > 0) {
         currentStatus = SCENARIO_1_AWAITING_BREAKOUT;
         if(settings.Enable_Logging) Print("پولبک به ناحیه طلایی در قیمت ", close[1], "، انتظار شکست Temporary_Low در ", temporary.price);
      }
   }
   else if(currentStatus == SCENARIO_1_AWAITING_BREAKOUT) {
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      if(low[1] < temporary.price) {
         if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, low[1], anchor.time, time[1], settings.SellEntryFibo_Color, "Scenario1");
         finalPoint.price = low[1];
         finalPoint.time = time[1];
         finalPoint.position = 1;
         finalFiboScenario = "Scenario1";
         currentStatus = SCENARIO_1_CONFIRMED_AWAITING_ENTRY;
         if(settings.Enable_Logging) Print("سناریو ۱ تأیید شد، Temporary_Low شکسته شد در ", low[1]);
      }
   }
   else if(currentStatus == SCENARIO_1_CONFIRMED_AWAITING_ENTRY) {
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], " در ", TimeToString(time[1]));
      }
   }
   else if(currentStatus == SCENARIO_2_ACTIVE_TARGETING_EXTENSION) {
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      if(low[1] < CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      double extensionLow = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_LowerLevel);
      double extensionHigh = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_UpperLevel);
      if(low[1] <= extensionLow) {
         if(low[1] < finalPoint.price || finalPoint.price == 0) {
            finalPoint.price = low[1];
            finalPoint.time = time[1];
            finalPoint.position = 1;
            if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.IntermediateFibo_Color, "Scenario2");
            if(settings.Enable_Logging && finalPoint.price > 0) Print("آپدیت کف نهایی سناریو ۲ در قیمت ", finalPoint.price, " در ", TimeToString(finalPoint.time));
         }
         if(low[1] > finalPoint.price && finalPoint.price > 0) {
            isPullbackStarted = true;
            if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.SellEntryFibo_Color, "Scenario2");
            finalFiboScenario = "Scenario2";
            currentStatus = SCENARIO_2_CONFIRMED_AWAITING_ENTRY;
            if(settings.Enable_Logging) Print("سناریو ۲ تأیید شد، پولبک از کف نهایی ", finalPoint.price, " شروع شد");
         }
      }
   }
   else if(currentStatus == SCENARIO_2_CONFIRMED_AWAITING_ENTRY) {
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      if(low[1] < CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close[1] >= goldenZoneLow && close[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close[1], " در ", TimeToString(time[1]));
      }
   }
   else if(currentStatus == ENTRY_ZONE_ACTIVE) {
   }
}

//+------------------------------------------------------------------+
//| یافتن دره (Find Valley)                                          |
//| این تابع نقاط پایین (دره) را در داده‌ها شناسایی می‌کند.          |
//+------------------------------------------------------------------+

bool CHipoFibonacci::FindValley(datetime &localTime, double &localPrice, int &localPosition) {
   if(rates_total < 2 * settings.Lookback + 1) return false;

   for(int i = MathMin(rates_total - settings.Lookback - 1, settings.MaxCandles - settings.Lookback - 1); i >= settings.Lookback; i--) {
      bool isValleyCandidate = true;
      if(settings.DetectionMethod != METHOD_ZIGZAG && settings.DetectionMethod != METHOD_BREAK_OF_STRUCTURE && settings.DetectionMethod != METHOD_MARKET_STRUCTURE_SHIFT) {
         for(int j = 1; j <= settings.Lookback; j++) {
            if(i - j >= 0 && low[i] >= low[i - j]) isValleyCandidate = false;
            if(i + j < rates_total && low[i] >= low[i + j]) isValleyCandidate = false;
         }
      }
      bool isFinalValley = false;
      switch(settings.DetectionMethod) {
         case METHOD_SIMPLE:
            isFinalValley = isValleyCandidate;
            break;
         case METHOD_SEQUENTIAL:
            isFinalValley = IsSequential(i, false);
            break;
         case METHOD_POWER_SWING:
            isFinalValley = HasEnoughPower(i, false, low[i], time[i]);
            break;
         case METHOD_ZIGZAG:
            isFinalValley = IsZigZag(i, false);
            break;
         case METHOD_BREAK_OF_STRUCTURE: {
            bool dummy;
            IdentifySwingPoints(i, dummy, isFinalValley);
            break;
         }
         case METHOD_MARKET_STRUCTURE_SHIFT: {
            bool dummy;
            IdentifyMSS(i, dummy, isFinalValley);
            break;
         }
      }
      if(isFinalValley) {
         localPrice = low[i];
         localTime = time[i];
         localPosition = i;
         lastConfirmedValley.price = localPrice;
         lastConfirmedValley.time = localTime;
         lastConfirmedValley.position = localPosition;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| یافتن قله (Find Peak)                                            |
//| این تابع نقاط بالا (قله) را در داده‌ها شناسایی می‌کند.           |
//+------------------------------------------------------------------+

bool CHipoFibonacci::FindPeak(datetime &localTime, double &localPrice, int &localPosition) {
   if(rates_total < 2 * settings.Lookback + 1) return false;

   for(int i = MathMin(rates_total - settings.Lookback - 1, settings.MaxCandles - settings.Lookback - 1); i >= settings.Lookback; i--) {
      bool isPeakCandidate = true;
      if(settings.DetectionMethod != METHOD_ZIGZAG && settings.DetectionMethod != METHOD_BREAK_OF_STRUCTURE && settings.DetectionMethod != METHOD_MARKET_STRUCTURE_SHIFT) {
         for(int j = 1; j <= settings.Lookback; j++) {
            if(i - j >= 0 && high[i] <= high[i - j]) isPeakCandidate = false;
            if(i + j < rates_total && high[i] <= high[i + j]) isPeakCandidate = false;
         }
      }
      bool isFinalPeak = false;
      switch(settings.DetectionMethod) {
         case METHOD_SIMPLE:
            isFinalPeak = isPeakCandidate;
            break;
         case METHOD_SEQUENTIAL:
            isFinalPeak = IsSequential(i, true);
            break;
         case METHOD_POWER_SWING:
            isFinalPeak = HasEnoughPower(i, true, high[i], time[i]);
            break;
         case METHOD_ZIGZAG:
            isFinalPeak = IsZigZag(i, true);
            break;
         case METHOD_BREAK_OF_STRUCTURE: {
            bool dummy;
            IdentifySwingPoints(i, isFinalPeak, dummy);
            break;
         }
         case METHOD_MARKET_STRUCTURE_SHIFT: {
            bool dummy;
            IdentifyMSS(i, isFinalPeak, dummy);
            break;
         }
      }
      if(isFinalPeak) {
         localPrice = high[i];
         localTime = time[i];
         localPosition = i;
         lastConfirmedPeak.price = localPrice;
         lastConfirmedPeak.time = localTime;
         lastConfirmedPeak.position = localPosition;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| بررسی ترتیب (Is Sequential)                                      |
//| این تابع ترتیب ترتیبی نقاط را بررسی می‌کند.                      |
//+------------------------------------------------------------------+

bool CHipoFibonacci::IsSequential(int i, bool isPeak) {
   if(i + settings.SequentialLookback >= rates_total) return false;

   if(settings.UseStrictSequential) {
      switch(settings.SequentialCriterion) {
         case CRITERION_HIGH:
            return CheckSequential(i, isPeak, high);
         case CRITERION_LOW:
            return CheckSequential(i, isPeak, low);
         case CRITERION_OPEN:
            return CheckSequential(i, isPeak, open);
         case CRITERION_CLOSE:
            return CheckSequential(i, isPeak, close);
      }
   } else {
      if(CheckSequential(i, isPeak, high)) return true;
      if(CheckSequential(i, isPeak, low)) return true;
      if(CheckSequential(i, isPeak, open)) return true;
      if(CheckSequential(i, isPeak, close)) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| بررسی ترتیبی (Check Sequential)                                  |
//| این تابع ترتیب دقیق نقاط را بر اساس آرایه داده‌ها بررسی می‌کند.  |
//+------------------------------------------------------------------+

bool CHipoFibonacci::CheckSequential(int i, bool isPeak, const double &values[]) {
   if(isPeak) {
      for(int k = 1; k <= settings.SequentialLookback; k++) {
         if(i - k >= 0) {
            if(values[i - k] >= values[i - k + 1]) return false;
         } else return false;
         if(i + k < rates_total) {
            if(values[i + k] > values[i + k - 1]) return false;
         } else return false;
      }
      return true;
   } else {
      for(int k = 1; k <= settings.SequentialLookback; k++) {
         if(i - k >= 0) {
            if(values[i - k] <= values[i - k + 1]) return false;
         } else return false;
         if(i + k < rates_total) {
            if(values[i + k] < values[i + k - 1]) return false;
         } else return false;
      }
      return true;
   }
}

//+------------------------------------------------------------------+
//| بررسی قدرت (Has Enough Power)                                    |
//| این تابع قدرت نقاط بر اساس شاخص ATR را بررسی می‌کند.             |
//+------------------------------------------------------------------+

bool CHipoFibonacci::HasEnoughPower(int i, bool isPeak, double price, datetime localTime) {
   if(isPeak) {
      if(lastConfirmedValley.price > 0 && localTime > lastConfirmedValley.time) {
         double distance = price - lastConfirmedValley.price;
         if(distance > settings.AtrMultiplier * atrBuffer[i]) {
            if(settings.Enable_Logging) Print("قله تأیید شد - فاصله: ", distance, " > ", settings.AtrMultiplier * atrBuffer[i]);
            return true;
         }
      } else {
         return true;
      }
   } else {
      if(lastConfirmedPeak.price > 0 && localTime > lastConfirmedPeak.time) {
         double distance = lastConfirmedPeak.price - price;
         if(distance > settings.AtrMultiplier * atrBuffer[i]) {
            if(settings.Enable_Logging) Print("دره تأیید شد - فاصله: ", distance, " > ", settings.AtrMultiplier * atrBuffer[i]);
            return true;
         }
      } else {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| بررسی زیgzاگ (Is ZigZag)                                        |
//| این تابع نقاط زیgzاگ را بر اساس انحراف و عمق بررسی می‌کند.      |
//+------------------------------------------------------------------+

bool CHipoFibonacci::IsZigZag(int i, bool isPeak) {
   if(i + settings.ZigZagDepth >= rates_total) return false;

   if(isPeak) {
      if(lastConfirmedValley.price > 0 && time[i] > lastConfirmedValley.time) {
         double distance = high[i] - lastConfirmedValley.price;
         if(distance > settings.ZigZagDeviation * _Point && i - lastConfirmedValley.position >= settings.ZigZagDepth) {
            if(settings.Enable_Logging) Print("قله زیgzاگ تأیید شد - فاصله: ", distance, " کندل‌ها: ", i - lastConfirmedValley.position);
            return true;
         }
      } else {
         return true;
      }
   } else {
      if(lastConfirmedPeak.price > 0 && time[i] > lastConfirmedPeak.time) {
         double distance = lastConfirmedPeak.price - low[i];
         if(distance > settings.ZigZagDeviation * _Point && i - lastConfirmedPeak.position >= settings.ZigZagDepth) {
            if(settings.Enable_Logging) Print("دره زیgzاگ تأیید شد - فاصله: ", distance, " کندل‌ها: ", i - lastConfirmedValley.position);
            return true;
         }
      } else {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| شناسایی نقاط چرخش (Identify Swing Points)                        |
//| این تابع نقاط چرخش بالا و پایین را شناسایی می‌کند.              |
//+------------------------------------------------------------------+

void CHipoFibonacci::IdentifySwingPoints(int i, bool &isSwingHigh, bool &isSwingLow) {
   if(i + settings.Lookback >= rates_total) return;

   isSwingHigh = true;
   isSwingLow = true;

   for(int j = 1; j <= settings.Lookback; j++) {
      if(i - j >= 0 && high[i] <= high[i - j]) isSwingHigh = false;
      if(i + j < rates_total && high[i] <= high[i + j]) isSwingHigh = false;
      if(i - j >= 0 && low[i] >= low[i - j]) isSwingLow = false;
      if(i + j < rates_total && low[i] >= low[i + j]) isSwingLow = false;
   }

   if(isSwingHigh) UpdateSwingArray(swingHighs_Array, swingHighs_Time, high[i], time[i]);
   if(isSwingLow) UpdateSwingArray(swingLows_Array, swingLows_Time, low[i], time[i]);
}

//+------------------------------------------------------------------+
//| شناسایی تغییر ساختار بازار (Identify MSS)                         |
//| این تابع تغییرات ساختار بازار را شناسایی می‌کند.                 |
//+------------------------------------------------------------------+

void CHipoFibonacci::IdentifyMSS(int i, bool &isFinalPeak, bool &isFinalValley) {
   if(i + settings.Lookback >= rates_total) return;

   bool isSwingHigh = true;
   bool isSwingLow = true;

   for(int j = 1; j <= settings.Lookback; j++) {
      if(i - j >= 0 && high[i] <= high[i - j]) isSwingHigh = false;
      if(i + j < rates_total && high[i] <= high[i + j]) isSwingHigh = false;
      if(i - j >= 0 && low[i] >= low[i - j]) isSwingLow = false;
      if(i + j < rates_total && low[i] >= low[i + j]) isSwingLow = false;
   }

   if(isSwingHigh) UpdateSwingArray(swingHighs_Array, swingHighs_Time, high[i], time[i]);
   if(isSwingLow) UpdateSwingArray(swingLows_Array, swingLows_Time, low[i], time[i]);

   if(isSwingHigh && ArraySize(swingHighs_Array) >= 2 && ArraySize(swingLows_Array) >= 2) {
      if(swingHighs_Array[1] > swingHighs_Array[0] && swingLows_Array[1] > swingLows_Array[0]) {
         isFinalPeak = true;
      }
   }

   if(isSwingLow && ArraySize(swingHighs_Array) >= 2 && ArraySize(swingLows_Array) >= 2) {
      if(swingHighs_Array[1] < swingHighs_Array[0] && swingLows_Array[1] < swingLows_Array[0]) {
         isFinalValley = true;
      }
   }
}

//+------------------------------------------------------------------+
//| به‌روزرسانی آرایه نقاط (Update Swing Array)                     |
//| این تابع آرایه نقاط چرخش را به‌روزرسانی می‌کند.                |
//+------------------------------------------------------------------+

void CHipoFibonacci::UpdateSwingArray(double &array[], datetime &timeArray[], double price, datetime localTime) {
   int size = ArraySize(array);
   if(size < 2) {
      ArrayResize(array, size + 1);
      ArrayResize(timeArray, size + 1);
      array[size] = price;
      timeArray[size] = localTime;
   } else {
      ArrayRemove(array, 0, 1);
      ArrayRemove(timeArray, 0, 1);
      ArrayResize(array, 2);
      ArrayResize(timeArray, 2);
      array[1] = price;
      timeArray[1] = localTime;
   }
}

//+------------------------------------------------------------------+
//| ایجاد پنل وضعیت (Create Status Panel)                            |
//| این تابع یک پنل وضعیت روی چارت ایجاد می‌کند.                     |
//+------------------------------------------------------------------+

void CHipoFibonacci::CreateStatusPanel() {
   ObjectCreate(0, "HipoFibonacci_Panel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_ZORDER, 0);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, "HipoFibonacci_Panel", OBJPROP_FONT, "Arial");
   UpdateStatusPanel();
}

//+------------------------------------------------------------------+
//| به‌روزرسانی پنل وضعیت (Update Status Panel)                     |
//| این تابع اطلاعات پنل وضعیت را به‌روزرسانی می‌کند.               |
//+------------------------------------------------------------------+

void CHipoFibonacci::UpdateStatusPanel() {
   if(!settings.Enable_Status_Panel) return;
   string statusText = "HipoFibonacci Library\n";
   statusText += "وضعیت: ";
   switch(currentStatus) {
      case WAITING_FOR_COMMAND: statusText += "منتظر دستور"; break;
      case SEARCHING_FOR_ANCHOR_LOW: statusText += "جستجوی کف لنگرگاه"; break;
      case SEARCHING_FOR_ANCHOR_HIGH: statusText += "جستجوی سقف لنگرگاه"; break;
      case MONITORING_SCENARIO_1_PROGRESS: statusText += "پایش سناریو ۱"; break;
      case SCENARIO_1_AWAITING_PULLBACK: statusText += "سناریو ۱ - انتظار پولبک"; break;
      case SCENARIO_1_AWAITING_BREAKOUT: statusText += "سناریو ۱ - انتظار شکست"; break;
      case SCENARIO_1_CONFIRMED_AWAITING_ENTRY: statusText += "سناریو ۱ - انتظار ورود"; break;
      case SCENARIO_2_ACTIVE_TARGETING_EXTENSION: statusText += "پایش سناریو ۲"; break;
      case SCENARIO_2_CONFIRMED_AWAITING_ENTRY: statusText += "سناریو ۲ - انتظار ورود"; break;
      case ENTRY_ZONE_ACTIVE: statusText += "ناحیه طلایی فعال"; break;
   }
   statusText += "\nدستور: ";
   color textColor = clrGray;
   switch(signalType) {
      case SIGNAL_BUY: statusText += "خرید"; textColor = clrGreen; break;
      case SIGNAL_SELL: statusText += "فروش"; textColor = clrRed; break;
      case STOP_SEARCH: statusText += "توقف"; textColor = clrGray; break;
   }
   ObjectSetString(0, "HipoFibonacci_Panel", OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_COLOR, textColor);
}

//+------------------------------------------------------------------+
//| رسم فیبوناچی (Draw Fibonacci)                                    |
//| این تابع سطوح فیبوناچی را روی چارت رسم می‌کند.                  |
//+------------------------------------------------------------------+

void CHipoFibonacci::DrawFibo(E_FiboType type, double price1, double price2, datetime time1, datetime time2, color clr, string scenario) {
   string name = "HipoFibo_" + EnumToString(type) + "_" + TimeToString(anchorID);
   if(scenario != "") name += "_" + scenario;
   ObjectCreate(0, name, OBJ_FIBO, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetString(0, name, OBJPROP_TEXT, scenario != "" ? scenario : EnumToString(type));
   for(int i = 0; i < settings.FibonacciLevelsCount; i++) {
      ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, i, settings.FibonacciLevels[i] / 100.0);
      ObjectSetString(0, name, OBJPROP_LEVELTEXT, i, DoubleToString(settings.FibonacciLevels[i], 1) + "%");
   }
   ObjectSetInteger(0, name, OBJPROP_LEVELS, settings.FibonacciLevelsCount);
}

//+------------------------------------------------------------------+
//| حذف اشیاء فیبوناچی (Delete Fibonacci Objects)                   |
//| این تابع اشیاء فیبوناچی را از چارت حذف می‌کند.                 |
//+------------------------------------------------------------------+

void CHipoFibonacci::DeleteFiboObjects() {
   string prefix = "HipoFibo_" + TimeToString(anchorID);
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) >= 0) ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| محاسبه قیمت سطح فیبوناچی (Calculate Fibonacci Level Price)      |
//| این تابع قیمت یک سطح فیبوناچی را بر اساس نوع و سطح محاسبه می‌کند. |
//+------------------------------------------------------------------+

double CHipoFibonacci::CalculateFiboLevelPrice(E_FiboType type, double level) {
   double price1 = 0, price2 = 0;
   if(type == FIBO_MOTHER && mother.price != 0) {
      price1 = anchor.price;
      price2 = mother.price;
   } else if(type == FIBO_INTERMEDIATE && temporary.price != 0) {
      price1 = anchor.price;
      price2 = temporary.price;
   } else if(type == FIBO_FINAL && finalPoint.price != 0) {
      price1 = anchor.price;
      price2 = finalPoint.price;
   } else {
      return 0;
   }
   double levelValue = level / 100.0;
   if(signalType == SIGNAL_BUY) {
      return price1 + (price2 - price1) * levelValue;
   } else {
      return price1 - (price1 - price2) * levelValue;
   }
}
