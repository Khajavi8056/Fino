//+------------------------------------------------------------------+
//| HipoFibonacci.mqh                                                |
//| Copyright © 2025 HipoAlgorithm                                   |
//| https://hipoalgorithm.com                                        |
//| نسخه: 2.0                                                        |
//| توضیحات: این فایل شامل کلاس CHipoFibonacci است که برای شناسایی لگ‌های حرکتی بازار با تأخیر صفر، رسم سطوح فیبوناچی و مدیریت استراتژی‌های معاملاتی در متاتریدر 5 طراحی شده است. |
//+------------------------------------------------------------------+

#property copyright "HipoAlgorithm"
#property link      "https://hipoalgorithm.com"
#property version   "2.0"
#property strict

//+------------------------------------------------------------------+
//| تعریف انوم‌ها (Enums)                                            |
//| این بخش شامل انوم‌هایی است که برای دسته‌بندی نوع سیگنال‌ها، وضعیت‌ها و نوع فیبوناچی استفاده می‌شوند. |
//+------------------------------------------------------------------+

enum E_SignalType {
   SIGNAL_BUY,          // سیگنال خرید
   SIGNAL_SELL,         // سیگنال فروش
   STOP_SEARCH          // توقف جستجو
};

enum E_Status {
   WAITING_FOR_COMMAND,            // منتظر دریافت دستور
   SEARCHING_FOR_LEG,              // جستجوی لگ حرکتی
   MONITORING_SCENARIO_1_PROGRESS, // پایش پیشرفت سناریو 1
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

//+------------------------------------------------------------------+
//| تعریف ساختارها (Structures)                                       |
//| این بخش شامل ساختارهایی برای ذخیره تنظیمات و نقاط لگ است.       |
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
   int KingPeakLookback;                 // بازه نگاه به عقب برای قله/دره پادشاه

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
//| این کلاس اصلی برای مدیریت منطق تشخیص لگ و رسم سطوح است.         |
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
   bool isInFocusMode;
   double high[];
   double low[];
   double open[];
   double close[];
   datetime time[];
   int rates_total;

   bool FindHipoLeg(PeakValley &mother_out, PeakValley &anchor_out); // یافتن لگ حرکتی
   void CreateStatusPanel();          // ایجاد پنل وضعیت
   void UpdateStatusPanel();          // به‌روزرسانی پنل وضعیت
   void DrawFibo(E_FiboType type, double price1, double price2, datetime time1, datetime time2, color clr, string scenario = ""); // رسم فیبوناچی
   void DrawLegLines();               // رسم خطوط لگ
   void DeleteFiboObjects();          // حذف اشیاء فیبوناچی
   void DeleteLegLines();             // حذف خطوط لگ
   double CalculateFiboLevelPrice(E_FiboType type, double level); // محاسبه قیمت سطح فیبوناچی
   void ProcessBuyLogic();            // پردازش منطق خرید
   void ProcessSellLogic();           // پردازش منطق فروش

public:
   CHipoFibonacci();                  // سازنده
   ~CHipoFibonacci();                 // نابودگر

   void Init(HipoSettings &inputSettings); // تنظیم اولیه
   void ReceiveCommand(E_SignalType type, ENUM_TIMEFRAMES timeframe); // دریافت دستور
   void OnNewCandle(const MqlRates &rates[]); // پردازش کندل جدید با دریافت آرایه MqlRates
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
   isInFocusMode = false;
}

//+------------------------------------------------------------------+
//| نابودگر (Destructor)                                             |
//| این تابع برای آزادسازی منابع هنگام نابودی شیء استفاده می‌شود.    |
//+------------------------------------------------------------------+

CHipoFibonacci::~CHipoFibonacci() {
   DeleteFiboObjects();
   DeleteLegLines();
   ObjectDelete(0, "HipoFibonacci_Panel");
   ObjectDelete(0, "HipoFibonacci_Panel_BG");
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
   settings.KingPeakLookback = inputSettings.KingPeakLookback > 0 ? inputSettings.KingPeakLookback : 100;

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

   if(settings.Enable_Status_Panel) CreateStatusPanel();
}

//+------------------------------------------------------------------+
//| دریافت دستور (Receive Command)                                   |
//| این تابع دستورهای خرید، فروش یا توقف را دریافت و پردازش می‌کند.  |
//+------------------------------------------------------------------+

void CHipoFibonacci::ReceiveCommand(E_SignalType type, ENUM_TIMEFRAMES timeframe) {
   if(isInFocusMode && type != STOP_SEARCH) {
      if(settings.Enable_Logging) Print("[HipoFibo] New command received, but system is in 'Focus Mode'. New command ignored.");
      return;
   }

   if(type == STOP_SEARCH) {
      if(settings.Enable_Logging) Print("دریافت دستور توقف جستجو");
      DeleteFiboObjects();
      DeleteLegLines();
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
      isInFocusMode = false;
      UpdateStatusPanel();
   } else {
      signalType = type;
      settings.CalculationTimeframe = timeframe == 0 ? PERIOD_CURRENT : timeframe;
      currentStatus = SEARCHING_FOR_LEG;
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
      isInFocusMode = false;
      if(settings.Enable_Logging) Print("دریافت دستور ", EnumToString(type), " در تایم‌فریم ", EnumToString(timeframe));
      UpdateStatusPanel();
   }
}

//+------------------------------------------------------------------+
//| پردازش کندل جدید (نسخه اصلاح شده با MqlRates)                     |
//| این تابع با دریافت آرایه MqlRates، داده‌های داخلی را به‌روز می‌کند. |
//+------------------------------------------------------------------+

void CHipoFibonacci::OnNewCandle(const MqlRates &rates[]) {
   if(currentStatus == WAITING_FOR_COMMAND) return;

   rates_total = ArraySize(rates);
   if (rates_total == 0) return; // اگر آرایه خالی بود، خارج شو

   // تغییر اندازه آرایه‌های داخلی
   ArrayResize(high, rates_total);
   ArrayResize(low, rates_total);
   ArrayResize(open, rates_total);
   ArrayResize(close, rates_total);
   ArrayResize(time, rates_total);

   // کپی داده‌ها از آرایه MqlRates به آرایه‌های داخلی کلاس
   for(int i = 0; i < rates_total; i++) {
      time[i]  = rates[i].time;
      open[i]  = rates[i].open;
      high[i]  = rates[i].high;
      low[i]   = rates[i].low;
      close[i] = rates[i].close;
   }

   // حالا که آرایه‌ها پر شدن، اونها رو به صورت سری تنظیم کن
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);

   // اجرای منطق اصلی
   if(signalType == SIGNAL_BUY) ProcessBuyLogic();
   else if(signalType == SIGNAL_SELL) ProcessSellLogic();

   UpdateStatusPanel();
}

//+------------------------------------------------------------------+
//| پردازش منطق خرید (Process Buy Logic)                             |
//| این تابع منطق مربوط به استراتژی خرید را مدیریت می‌کند.           |
//+------------------------------------------------------------------+

void CHipoFibonacci::ProcessBuyLogic() {
   if(currentStatus == SEARCHING_FOR_LEG && !isInFocusMode) {
      PeakValley localMother, localAnchor;
      if(FindHipoLeg(localMother, localAnchor)) {
         mother = localMother;
         anchor = localAnchor;
         anchorID = localAnchor.time;
         isInFocusMode = true;
         if(settings.Enable_Drawing) {
            DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
            DrawLegLines();
         }
         if(settings.Enable_Logging) Print("لگ خرید یافت شد: Mother_High در قیمت ", mother.price, " در ", TimeToString(mother.time), ", Anchor_Low در ", anchor.price);
         currentStatus = MONITORING_SCENARIO_1_PROGRESS;
      } else {
         if(settings.Enable_Logging) Print("[HipoFibo] Not enough candle data to find a leg");
      }
   }
   else if(currentStatus == MONITORING_SCENARIO_1_PROGRESS) {
      if(settings.Enable_Drawing) DrawFibo(FIBO_INTERMEDIATE, anchor.price, high[1], anchor.time, time[1], settings.IntermediateFibo_Color);
      if(low[1] < anchor.price - settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
         return;
      }
      if(high[1] > mother.price) {
         currentStatus = SCENARIO_2_ACTIVE_TARGETING_EXTENSION;
         temporary.price = 0;
         temporary.time = 0;
         temporary.position = 0;
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
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
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
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
         return;
      }
      if(high[1] > CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
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
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
         return;
      }
      if(high[1] > CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
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
   if(currentStatus == SEARCHING_FOR_LEG && !isInFocusMode) {
      PeakValley localMother, localAnchor;
      if(FindHipoLeg(localMother, localAnchor)) {
         mother = localMother;
         anchor = localAnchor;
         anchorID = localAnchor.time;
         isInFocusMode = true;
         if(settings.Enable_Drawing) {
            DrawFibo(FIBO_MOTHER, anchor.price, mother.price, anchor.time, mother.time, settings.MotherFibo_Color);
            DrawLegLines();
         }
         if(settings.Enable_Logging) Print("لگ فروش یافت شد: Mother_Low در قیمت ", mother.price, " در ", TimeToString(mother.time), ", Anchor_High در ", anchor.price);
         currentStatus = MONITORING_SCENARIO_1_PROGRESS;
      } else {
         if(settings.Enable_Logging) Print("[HipoFibo] Not enough candle data to find a leg");
      }
   }
   else if(currentStatus == MONITORING_SCENARIO_1_PROGRESS) {
      if(settings.Enable_Drawing) DrawFibo(FIBO_INTERMEDIATE, anchor.price, low[1], anchor.time, time[1], settings.IntermediateFibo_Color);
      if(high[1] > anchor.price + settings.MarginPips * _Point) {
         if(settings.Enable_Logging) Print("شکست ساختار: لنگرگاه شکسته در قیمت ", high[1]);
         DeleteFiboObjects();
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
         return;
      }
      if(low[1] < mother.price) {
         currentStatus = SCENARIO_2_ACTIVE_TARGETING_EXTENSION;
         temporary.price = 0;
         temporary.time = 0;
         temporary.position = 0;
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
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
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
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
         return;
      }
      if(low[1] < CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
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
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
         return;
      }
      if(low[1] < CalculateFiboLevelPrice(FIBO_MOTHER, 200.0)) {
         if(settings.Enable_Logging) Print("شکست ساختار: اکستنشن شکسته در قیمت ", low[1]);
         DeleteFiboObjects();
         DeleteLegLines();
         currentStatus = SEARCHING_FOR_LEG;
         isInFocusMode = false;
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
//| یافتن لگ حرکتی (نسخه نهایی، بهینه و حرفه‌ای)                       |
//+------------------------------------------------------------------+

bool CHipoFibonacci::FindHipoLeg(PeakValley &mother_out, PeakValley &anchor_out) {
    int lookback = settings.KingPeakLookback;
    if (rates_total < lookback) {
        if(settings.Enable_Logging) Print("[HipoFibo] Not enough candle data to find a leg");
        return false;
    }

    if (signalType == SIGNAL_BUY) {
        // 1. یافتن قله پادشاه در X کندل اخیر (از کندل 1 تا X)
        int kingPeakIndex = ArrayMaximum(high, 1, lookback);
        if (kingPeakIndex == -1) return false;

        mother_out.price = high[kingPeakIndex];
        mother_out.time = time[kingPeakIndex];
        mother_out.position = kingPeakIndex;

        // 2. یافتن دره زنده از قله پادشاه تا کندل فعلی
        int liveValleyIndex = ArrayMinimum(low, 1, kingPeakIndex);
        if (liveValleyIndex == -1) return false;

        anchor_out.price = low[liveValleyIndex];
        anchor_out.time = time[liveValleyIndex];
        anchor_out.position = liveValleyIndex;

        // 3. اعتبارسنجی لگ
        if (mother_out.position > anchor_out.position && (mother_out.position - anchor_out.position) > 2) {
            return true;
        }

    } else if (signalType == SIGNAL_SELL) {
        // 1. یافتن دره پادشاه
        int kingValleyIndex = ArrayMinimum(low, 1, lookback);
        if (kingValleyIndex == -1) return false;

        mother_out.price = low[kingValleyIndex];
        mother_out.time = time[kingValleyIndex];
        mother_out.position = kingValleyIndex;

        // 2. یافتن قله زنده
        int livePeakIndex = ArrayMaximum(high, 1, kingValleyIndex);
        if (livePeakIndex == -1) return false;

        anchor_out.price = high[livePeakIndex];
        anchor_out.time = time[livePeakIndex];
        anchor_out.position = livePeakIndex;

        // 3. اعتبارسنجی لگ
        if (mother_out.position > anchor_out.position && (mother_out.position - anchor_out.position) > 2) {
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| رسم خطوط لگ (Draw Leg Lines)                                     |
//| این تابع خطوط افقی نقطه‌چین برای Mother و Anchor رسم می‌کند.     |
//+------------------------------------------------------------------+

void CHipoFibonacci::DrawLegLines() {
   string mother_name = "HipoLine_Mother_" + TimeToString(anchorID);
   string anchor_name = "HipoLine_Anchor_" + TimeToString(anchorID);
   color anchor_color = (signalType == SIGNAL_BUY) ? settings.BuyEntryFibo_Color : settings.SellEntryFibo_Color;

   ObjectCreate(0, mother_name, OBJ_HLINE, 0, 0, mother.price);
   ObjectSetInteger(0, mother_name, OBJPROP_COLOR, settings.MotherFibo_Color);
   ObjectSetInteger(0, mother_name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, mother_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, mother_name, OBJPROP_RAY, true);
   ObjectSetString(0, mother_name, OBJPROP_TEXT, "Mother Level");

   ObjectCreate(0, anchor_name, OBJ_HLINE, 0, 0, anchor.price);
   ObjectSetInteger(0, anchor_name, OBJPROP_COLOR, anchor_color);
   ObjectSetInteger(0, anchor_name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, anchor_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, anchor_name, OBJPROP_RAY, true);
   ObjectSetString(0, anchor_name, OBJPROP_TEXT, "Anchor Level");
}

//+------------------------------------------------------------------+
//| حذف خطوط لگ (Delete Leg Lines)                                   |
//| این تابع خطوط افقی لگ را از چارت حذف می‌کند.                    |
//+------------------------------------------------------------------+

void CHipoFibonacci::DeleteLegLines() {
   string prefix = "HipoLine_" + TimeToString(anchorID);
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) >= 0) ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| ایجاد پنل وضعیت (Create Status Panel)                            |
//| این تابع یک پنل وضعیت گرافیکی روی چارت ایجاد می‌کند.            |
//+------------------------------------------------------------------+

void CHipoFibonacci::CreateStatusPanel() {
   // ایجاد کادر پس‌زمینه
   ObjectCreate(0, "HipoFibonacci_Panel_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_XSIZE, 200);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_YSIZE, 80);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "HipoFibonacci_Panel_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);

   // ایجاد متن پنل
   ObjectCreate(0, "HipoFibonacci_Panel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_YDISTANCE, 15);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "HipoFibonacci_Panel", OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, "HipoFibonacci_Panel", OBJPROP_FONT, "Arial");
   UpdateStatusPanel();
}

//+------------------------------------------------------------------+
//| به‌روزرسانی پنل وضعیت (Update Status Panel)                     |
//| این تابع اطلاعات پنل وضعیت را به‌روزرسانی می‌کند.               |
//+------------------------------------------------------------------+

void CHipoFibonacci::UpdateStatusPanel() {
   if(!settings.Enable_Status_Panel) return;
   string statusText = "HipoFibonacci v2.0\n";
   statusText += "وضعیت: ";
   switch(currentStatus) {
      case WAITING_FOR_COMMAND: statusText += "منتظر دستور"; break;
      case SEARCHING_FOR_LEG: statusText += "جستجوی لگ حرکتی"; break;
      case MONITORING_SCENARIO_1_PROGRESS: statusText += "پایش سناریو ۱"; break;
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
   if(isInFocusMode) statusText += "\nحالت تمرکز: فعال";
   else statusText += "\nحالت تمرکز: غیرفعال";
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
