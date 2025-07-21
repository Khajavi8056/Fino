//+------------------------------------------------------------------+
//| HipoFibonacci.mqh                                                |
//| Copyright © 2025 HipoAlgorithm                                   |
//| https://hipoalgorithm.com                                        |
//| نسخه: 1.4                                                        |
//| توضیحات: این فایل شامل کلاس CHipoFibonacci است که با استفاده از اندیکاتور Fineflow برای شناسایی نقاط چرخش بازار، سطوح فیبوناچی را رسم و استراتژی‌های معاملاتی را مدیریت می‌کند. |
//+------------------------------------------------------------------+

#property copyright "HipoAlgorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.4"
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
   METHOD_ZIGZAG,                // روش زیgzاگ
   METHOD_BREAK_OF_STRUCTURE,    // روش شکست ساختار
   METHOD_MARKET_STRUCTURE_SHIFT // روش تغییر ساختار بازار
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
   ENUM_TIMEFRAMES ExecutionTimeframe;   // تایم‌فریم اجرایی اندیکاتور
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
   int AtrPeriod;                        // دوره ATR
   double AtrMultiplier;                 // ضریب ATR
   int ZigZagDepth;                      // عمق زیgzاگ
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
   int handleFineflow;                  // هندل اندیکاتور Fineflow
   double peakBuffer[];                 // بافر قله‌ها از Fineflow
   double valleyBuffer[];               // بافر دره‌ها از Fineflow

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
   handleFineflow = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| نابودگر (Destructor)                                             |
//| این تابع برای آزادسازی منابع هنگام نابودی شیء استفاده می‌شود.    |
//+------------------------------------------------------------------+

CHipoFibonacci::~CHipoFibonacci() {
   if(handleFineflow != INVALID_HANDLE) IndicatorRelease(handleFineflow);
   DeleteFiboObjects();
   ObjectDelete(0, "HipoFibonacci_Panel");
}

//+------------------------------------------------------------------+
//| تنظیم اولیه (Initialization)                                     |
//| این تابع تنظیمات اولیه را بر اساس ورودی‌ها اعمال می‌کند.         |
//+------------------------------------------------------------------+

void CHipoFibonacci::Init(HipoSettings &inputSettings) {
   settings.CalculationTimeframe = inputSettings.CalculationTimeframe == 0 ? PERIOD_CURRENT : inputSettings.CalculationTimeframe;
   settings.ExecutionTimeframe = inputSettings.ExecutionTimeframe == 0 ? PERIOD_CURRENT : inputSettings.ExecutionTimeframe;
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

   // ایجاد هندل برای اندیکاتور Fineflow
   handleFineflow = iCustom(_Symbol, settings.ExecutionTimeframe, "Fineflow",
                            settings.EnforceStrictSequence,
                            settings.DetectionMethod,
                            settings.Lookback,
                            settings.SequentialLookback,
                            settings.UseStrictSequential,
                            settings.SequentialCriterion,
                            settings.AtrPeriod,
                            settings.AtrMultiplier,
                            settings.ZigZagDepth,
                            settings.ZigZagDeviation,
                            settings.Enable_Logging);
   if(handleFineflow == INVALID_HANDLE && settings.Enable_Logging) Print("خطا در ایجاد هندل اندیکاتور Fineflow");

   ArrayResize(peakBuffer, settings.MaxCandles);
   ArrayResize(valleyBuffer, settings.MaxCandles);

   if(settings.Enable_Status_Panel) CreateStatusPanel();
}

//+------------------------------------------------------------------+
//| دریافت دستور (Receive Command)                                   |
//| این تابع دستورهای خرید، فروش یا توقف را دریافت و پردازش می‌کند.  |
//+------------------------------------------------------------------+

void CHipoFibonacci::ReceiveCommand(E_SignalType type, ENUM_TIMEFRAMES timeframe) {
   if(handleFineflow != INVALID_HANDLE) IndicatorRelease(handleFineflow);
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
      UpdateStatusPanel();
   } else {
      signalType = type;
      settings.ExecutionTimeframe = timeframe == 0 ? PERIOD_CURRENT : timeframe;
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
      handleFineflow = iCustom(_Symbol, settings.ExecutionTimeframe, "Fineflow",
                               settings.EnforceStrictSequence,
                               settings.DetectionMethod,
                               settings.Lookback,
                               settings.SequentialLookback,
                               settings.UseStrictSequential,
                               settings.SequentialCriterion,
                               settings.AtrPeriod,
                               settings.AtrMultiplier,
                               settings.ZigZagDepth,
                               settings.ZigZagDeviation,
                               settings.Enable_Logging);
      if(handleFineflow == INVALID_HANDLE && settings.Enable_Logging) Print("خطا در ایجاد هندل اندیکاتور Fineflow");
      if(settings.Enable_Logging) Print("دریافت دستور ", EnumToString(type), " در تایم‌فریم ", EnumToString(timeframe));
      UpdateStatusPanel();
   }
}

//+------------------------------------------------------------------+
//| پردازش کندل جدید (On New Candle)                                 |
//| این تابع با دریافت داده‌های جدید کندل، منطق را به‌روزرسانی می‌کند. |
//+------------------------------------------------------------------+

void CHipoFibonacci::OnNewCandle(const int rates_total_input, const datetime &time_input[], const double &open_input[], const double &high_input[], const double &low_input[], const double &close_input[]) {
   if(currentStatus == WAITING_FOR_COMMAND || handleFineflow == INVALID_HANDLE) return;

   // کپی بافرهای اندیکاتور Fineflow
   if(CopyBuffer(handleFineflow, 0, 0, MathMin(rates_total_input, settings.MaxCandles), peakBuffer) <= 0 ||
      CopyBuffer(handleFineflow, 1, 0, MathMin(rates_total_input, settings.MaxCandles), valleyBuffer) <= 0) {
      if(settings.Enable_Logging) Print("خطا در کپی بافرهای اندیکاتور Fineflow");
      return;
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
   int latestIndex = 0;
   while(latestIndex < ArraySize(peakBuffer) && peakBuffer[latestIndex] == 0.0) latestIndex++;
   if(latestIndex >= ArraySize(peakBuffer)) return;

   if(currentStatus == SEARCHING_FOR_ANCHOR_LOW) {
      int valleyIndex = 0;
      while(valleyIndex < ArraySize(valleyBuffer) && valleyBuffer[valleyIndex] == 0.0) valleyIndex++;
      if(valleyIndex < ArraySize(valleyBuffer) && valleyIndex <= latestIndex) {
         anchor.price = valleyBuffer[valleyIndex];
         anchor.time = time_input[valleyIndex];
         anchor.position = valleyIndex;
         anchorID = anchor.time;
         int peakIndex = 0;
         while(peakIndex < ArraySize(peakBuffer) && peakBuffer[peakIndex] == 0.0) peakIndex++;
         if(peakIndex < valleyIndex) {
            mother.price = peakBuffer[peakIndex];
            mother.time = time_input[peakIndex];
            mother.position = peakIndex;
            if(settings.Enable_Drawing) DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
            if(settings.Enable_Logging) Print("Anchor_Low یافت شد در قیمت ", anchor.price, " در ", TimeToString(anchor.time), ", Mother_High در ", mother.price);
            currentStatus = MONITORING_SCENARIO_1_PROGRESS;
         }
      }
   }
   else if(currentStatus == MONITORING_SCENARIO_1_PROGRESS) {
      if(settings.Enable_Drawing) DrawFibo(FIBO_INTERMEDIATE, anchor.price, high_input[1], anchor.time, time_input[1], settings.IntermediateFibo_Color);
      if(low_input[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      int tempIndex = 0;
      while(tempIndex < ArraySize(peakBuffer) && (peakBuffer[tempIndex] == 0.0 || tempIndex <= mother.position)) tempIndex++;
      if(tempIndex < ArraySize(peakBuffer)) {
         temporary.price = peakBuffer[tempIndex];
         temporary.time = time_input[tempIndex];
         temporary.position = tempIndex;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_UpperLevel);
      if(close_input[1] >= goldenZoneLow && close_input[1] <= goldenZoneHigh && temporary.price > 0) {
         currentStatus = SCENARIO_1_AWAITING_BREAKOUT;
         if(settings.Enable_Logging) Print("پولبک به ناحیه طلایی در قیمت ", close_input[1], "، انتظار شکست Temporary_High در ", temporary.price);
      }
      if(high_input[1] > mother.price) {
         currentStatus = SCENARIO_2_ACTIVE_TARGETING_EXTENSION;
         isEntryZoneActive = false;
         finalPoint.price = 0;
         finalPoint.time = 0;
         finalPoint.position = 0;
         if(settings.Enable_Logging) Print("ورود به سناریو ۲: شکست Mother_High در ", high_input[1]);
         return;
      }
   }
   else if(currentStatus == SCENARIO_1_AWAITING_BREAKOUT) {
      if(low_input[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      int tempIndex = 0;
      while(tempIndex < ArraySize(peakBuffer) && peakBuffer[tempIndex] == 0.0) tempIndex++;
      if(tempIndex < ArraySize(peakBuffer) && high_input[tempIndex] > temporary.price) {
         if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, high_input[tempIndex], anchor.time, time_input[tempIndex], settings.BuyEntryFibo_Color, "Scenario1");
         finalPoint.price = high_input[tempIndex];
         finalPoint.time = time_input[tempIndex];
         finalPoint.position = tempIndex;
         finalFiboScenario = "Scenario1";
         currentStatus = SCENARIO_1_CONFIRMED_AWAITING_ENTRY;
         if(settings.Enable_Logging) Print("سناریو ۱ تأیید شد، Temporary_High شکسته شد در ", high_input[tempIndex]);
      }
   }
   else if(currentStatus == SCENARIO_1_CONFIRMED_AWAITING_ENTRY) {
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close_input[1] >= goldenZoneLow && close_input[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time_input[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close_input[1], " در ", TimeToString(time_input[1]));
      }
   }
   else if(currentStatus == SCENARIO_2_ACTIVE_TARGETING_EXTENSION) {
      if(low_input[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لnگرگاه شکسته در قیمت ", low_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      if(high_input[1] > CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", high_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      double extensionLow = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_LowerLevel);
      double extensionHigh = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_UpperLevel);
      if(high_input[1] >= extensionLow) {
         int finalIndex = 0;
         while(finalIndex < ArraySize(peakBuffer) && peakBuffer[finalIndex] == 0.0) finalIndex++;
         if(finalIndex < ArraySize(peakBuffer) && high_input[finalIndex] > finalPoint.price) {
            finalPoint.price = high_input[finalIndex];
            finalPoint.time = time_input[finalIndex];
            finalPoint.position = finalIndex;
            if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.IntermediateFibo_Color, "Scenario2");
            if(settings.Enable_Logging && finalPoint.price > 0) Print("آپدیت سقف نهایی سناریو ۲ در قیمت ", finalPoint.price, " در ", TimeToString(finalPoint.time));
         }
         if(high_input[1] < finalPoint.price && finalPoint.price > 0) {
            isEntryZoneActive = false;
            if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.BuyEntryFibo_Color, "Scenario2");
            finalFiboScenario = "Scenario2";
            currentStatus = SCENARIO_2_CONFIRMED_AWAITING_ENTRY;
            if(settings.Enable_Logging) Print("سناریو ۲ تأیید شد، پولبک از سقف نهایی ", finalPoint.price, " شروع شد");
         }
      }
   }
   else if(currentStatus == SCENARIO_2_CONFIRMED_AWAITING_ENTRY) {
      if(low_input[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      if(high_input[1] > CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", high_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_LOW : WAITING_FOR_COMMAND;
         return;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close_input[1] >= goldenZoneLow && close_input[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time_input[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close_input[1], " در ", TimeToString(time_input[1]));
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
   int latestIndex = 0;
   while(latestIndex < ArraySize(valleyBuffer) && valleyBuffer[latestIndex] == 0.0) latestIndex++;
   if(latestIndex >= ArraySize(valleyBuffer)) return;

   if(currentStatus == SEARCHING_FOR_ANCHOR_HIGH) {
      int peakIndex = 0;
      while(peakIndex < ArraySize(peakBuffer) && peakBuffer[peakIndex] == 0.0) peakIndex++;
      if(peakIndex < ArraySize(peakBuffer) && peakIndex <= latestIndex) {
         anchor.price = peakBuffer[peakIndex];
         anchor.time = time_input[peakIndex];
         anchor.position = peakIndex;
         anchorID = anchor.time;
         int valleyIndex = 0;
         while(valleyIndex < ArraySize(valleyBuffer) && valleyBuffer[valleyIndex] == 0.0) valleyIndex++;
         if(valleyIndex < peakIndex) {
            mother.price = valleyBuffer[valleyIndex];
            mother.time = time_input[valleyIndex];
            mother.position = valleyIndex;
            if(settings.Enable_Drawing) DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
            if(settings.Enable_Logging) Print("Anchor_High یافت شد در قیمت ", anchor.price, " در ", TimeToString(anchor.time), ", Mother_Low در ", mother.price);
            currentStatus = MONITORING_SCENARIO_1_PROGRESS;
         }
      }
   }
   else if(currentStatus == MONITORING_SCENARIO_1_PROGRESS) {
      if(settings.Enable_Drawing) DrawFibo(FIBO_INTERMEDIATE, anchor.price, low_input[1], anchor.time, time_input[1], settings.IntermediateFibo_Color);
      if(high_input[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      int tempIndex = 0;
      while(tempIndex < ArraySize(valleyBuffer) && (valleyBuffer[tempIndex] == 0.0 || tempIndex <= mother.position)) tempIndex++;
      if(tempIndex < ArraySize(valleyBuffer)) {
         temporary.price = valleyBuffer[tempIndex];
         temporary.time = time_input[tempIndex];
         temporary.position = tempIndex;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_INTERMEDIATE, settings.EntryZone_UpperLevel);
      if(close_input[1] >= goldenZoneLow && close_input[1] <= goldenZoneHigh && temporary.price > 0) {
         currentStatus = SCENARIO_1_AWAITING_BREAKOUT;
         if(settings.Enable_Logging) Print("پولبک به ناحیه طلایی در قیمت ", close_input[1], "، انتظار شکست Temporary_Low در ", temporary.price);
      }
      if(low_input[1] < mother.price) {
         currentStatus = SCENARIO_2_ACTIVE_TARGETING_EXTENSION;
         isEntryZoneActive = false;
         finalPoint.price = 0;
         finalPoint.time = 0;
         finalPoint.position = 0;
         if(settings.Enable_Logging) Print("ورود به سناریو ۲: شکست Mother_Low در ", low_input[1]);
         return;
      }
   }
   else if(currentStatus == SCENARIO_1_AWAITING_BREAKOUT) {
      if(high_input[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      int tempIndex = 0;
      while(tempIndex < ArraySize(valleyBuffer) && valleyBuffer[tempIndex] == 0.0) tempIndex++;
      if(tempIndex < ArraySize(valleyBuffer) && low_input[tempIndex] < temporary.price) {
         if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, low_input[tempIndex], anchor.time, time_input[tempIndex], settings.SellEntryFibo_Color, "Scenario1");
         finalPoint.price = low_input[tempIndex];
         finalPoint.time = time_input[tempIndex];
         finalPoint.position = tempIndex;
         finalFiboScenario = "Scenario1";
         currentStatus = SCENARIO_1_CONFIRMED_AWAITING_ENTRY;
         if(settings.Enable_Logging) Print("سناریو ۱ تأیید شد، Temporary_Low شکسته شد در ", low_input[tempIndex]);
      }
   }
   else if(currentStatus == SCENARIO_1_CONFIRMED_AWAITING_ENTRY) {
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close_input[1] >= goldenZoneLow && close_input[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time_input[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close_input[1], " در ", TimeToString(time_input[1]));
      }
   }
   else if(currentStatus == SCENARIO_2_ACTIVE_TARGETING_EXTENSION) {
      if(high_input[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      if(low_input[1] < CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", low_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      double extensionLow = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_LowerLevel);
      double extensionHigh = CalculateFiboLevelPrice(FIBO_MOTHER, settings.ExtensionZone_UpperLevel);
      if(low_input[1] <= extensionLow) {
         int finalIndex = 0;
         while(finalIndex < ArraySize(valleyBuffer) && valleyBuffer[finalIndex] == 0.0) finalIndex++;
         if(finalIndex < ArraySize(valleyBuffer) && low_input[finalIndex] < finalPoint.price) {
            finalPoint.price = low_input[finalIndex];
            finalPoint.time = time_input[finalIndex];
            finalPoint.position = finalIndex;
            if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.IntermediateFibo_Color, "Scenario2");
            if(settings.Enable_Logging && finalPoint.price > 0) Print("آپدیت کف نهایی سناریو ۲ در قیمت ", finalPoint.price, " در ", TimeToString(finalPoint.time));
         }
         if(low_input[1] > finalPoint.price && finalPoint.price > 0) {
            isEntryZoneActive = false;
            if(settings.Enable_Drawing) DrawFibo(FIBO_FINAL, anchor.price, finalPoint.price, anchor.time, finalPoint.time, settings.SellEntryFibo_Color, "Scenario2");
            finalFiboScenario = "Scenario2";
            currentStatus = SCENARIO_2_CONFIRMED_AWAITING_ENTRY;
            if(settings.Enable_Logging) Print("سناریو ۲ تأیید شد، پولبک از کف نهایی ", finalPoint.price, " شروع شد");
         }
      }
   }
   else if(currentStatus == SCENARIO_2_CONFIRMED_AWAITING_ENTRY) {
      if(high_input[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      if(low_input[1] < CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", low_input[1]);
         DeleteFiboObjects();
         currentStatus = (signalType != STOP_SEARCH) ? SEARCHING_FOR_ANCHOR_HIGH : WAITING_FOR_COMMAND;
         return;
      }
      double goldenZoneLow = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_LowerLevel);
      double goldenZoneHigh = CalculateFiboLevelPrice(FIBO_FINAL, settings.EntryZone_UpperLevel);
      if(close_input[1] >= goldenZoneLow && close_input[1] <= goldenZoneHigh) {
         isEntryZoneActive = true;
         entryZoneActivationTime = time_input[1];
         currentStatus = ENTRY_ZONE_ACTIVE;
         if(settings.Enable_Logging) Print("ناحیه طلایی فعال در قیمت ", close_input[1], " در ", TimeToString(time_input[1]));
      }
   }
   else if(currentStatus == ENTRY_ZONE_ACTIVE) {
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
