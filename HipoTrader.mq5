/*+------------------------------------------------------------------+
//| HipoTrader.mq5                                                  |
//| Copyright © 2025 HipoAlgorithm                                   |
//| https://hipoalgorithm.com                                        |
//| نسخه: 1.2                                                        |
//| توضیحات: این اکسپرت با استفاده از اندیکاتور MACD در دو تایم‌فریم، جهت بازار را تشخیص داده و با کتابخانه HipoFibonacci (نسخه 1.3) نقاط ورود بهینه را محاسبه می‌کند. مدیریت ریسک، رابط کاربری و تنظیمات چارت به‌صورت استاندارد و بهینه پیاده‌سازی شده است.
//| هماهنگی: این کد با آخرین نسخه کتابخانه HipoFibonacci.mqh (1.3) طراحی شده و از ساختارها و توابع آن به‌صورت دقیق استفاده می‌کند.
//+------------------------------------------------------------------*/

#property copyright "HipoAlgorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.2"
#property strict

// شامل کردن کتابخانه‌های مورد نیاز
#include <HipoFibonacci.mqh>
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| متغیرهای سراسری                                                 |
//| این بخش شامل متغیرهای اصلی اکسپرت است که در کل برنامه استفاده می‌شوند.
//| - HipoFibo: نمونه از کلاس CHipoFibonacci برای مدیریت سطوح فیبوناچی
//| - trade: شیء برای مدیریت معاملات با استفاده از CTrade
//| - macd_handles: هندل‌های اندیکاتور MACD برای دو تایم‌فریم
//| - currentTrend: وضعیت فعلی روند بازار (صعودی، نزولی، یا خنثی)
//| - lastBarTime: زمان آخرین کندل برای تشخیص کندل جدید
//| - lastError: ذخیره آخرین خطای رخ‌داده برای لاگ یا نمایش
//+------------------------------------------------------------------+

CHipoFibonacci HipoFibo;                // نمونه از کلاس CHipoFibonacci برای مدیریت فیبوناچی
CTrade trade;                           // کلاس استاندارد متاتریدر برای مدیریت معاملات
int macd_htf_handle;                    // هندل برای اندیکاتور MACD در تایم‌فریم بالا
int macd_mtf_handle;                    // هندل برای اندیکاتور MACD در تایم‌فریم میانی
enum E_Trend { TREND_UP, TREND_DOWN, NEUTRAL }; // تعریف انوم برای وضعیت روند
E_Trend currentTrend = NEUTRAL;         // وضعیت فعلی روند بازار
HipoSettings fiboSettings;              // ساختار تنظیمات برای کتابخانه HipoFibonacci
datetime lastBarTime = 0;               // زمان آخرین کندل پردازش‌شده
string lastError = "";                  // ذخیره آخرین خطا برای گزارش‌دهی

//+------------------------------------------------------------------+
//| پارامترهای ورودی                                                 |
//| این بخش شامل تنظیمات قابل تغییر توسط کاربر است که به صورت گروه‌بندی شده تعریف شده‌اند.
//| - تنظیمات اصلی: پارامترهای کلی مانند ریسک، تعداد معاملات، و شماره جادویی
//| - تنظیمات سیگنال‌دهی: پارامترهای اندیکاتور MACD برای دو تایم‌فریم
//| - تنظیمات نمایش: گزینه‌های بصری و فیلترها برای بهبود عملکرد
//+------------------------------------------------------------------+

input group "تنظیمات اصلی HipoTrader"
input int MagicNumber = 123456;         // شماره جادویی برای شناسایی معاملات اکسپرت
input double Risk_Percentage_Per_Trade = 1.0; // درصد ریسک در هر معامله (0.1 تا 5.0)
input double Risk_Reward_Ratio = 2.0;   // نسبت ریسک به ریوارد (1.0 تا 5.0)
input double SL_Buffer_Pips = 5.0;      // فاصله اضافی استاپ لاس به پیپ
input int Max_Open_Trades = 1;          // حداکثر تعداد معاملات باز مجاز

input group "تنظیمات سیگنال‌دهی MACD HTF (4x)"
input ENUM_TIMEFRAMES HTF_Timeframe = PERIOD_H1; // تایم‌فریم بالا برای تحلیل روند
input int HTF_Fast_EMA = 48;            // دوره EMA سریع (4x مقیاس استاندارد)
input int HTF_Slow_EMA = 104;           // دوره EMA کند (4x مقیاس استاندارد)
input int HTF_Signal_SMA = 36;          // دوره SMA سیگنال (4x مقیاس استاندارد)
input color HTF_MACD_Color = clrBlue;   // رنگ خط MACD برای نمایش HTF
input color HTF_Signal_Color = clrRed;  // رنگ خط سیگنال برای نمایش HTF

input group "تنظیمات سیگنال‌دهی MACD MTF (0.5x)"
input ENUM_TIMEFRAMES MTF_Timeframe = PERIOD_M15; // تایم‌فریم میانی برای ماشه
input int MTF_Fast_EMA = 6;             // دوره EMA سریع (0.5x مقیاس استاندارد)
input int MTF_Slow_EMA = 13;            // دوره EMA کند (0.5x مقیاس استاندارد)
input int MTF_Signal_SMA = 5;           // دوره SMA سیگنال (0.5x مقیاس استاندارد)
input color MTF_MACD_Color = clrGreen;  // رنگ خط MACD برای نمایش MTF
input color MTF_Signal_Color = clrYellow; // رنگ خط سیگنال برای نمایش MTF

input group "تنظیمات نمایش و چارت"
input bool Enable_MACD_Display = true;  // فعال‌سازی نمایش اندیکاتورهای MACD روی چارت
input bool Enable_Confirmation_Filter = false; // فعال‌سازی فیلتر تأیید کندل بعدی

//+------------------------------------------------------------------+
//| تابع راه‌اندازی اولیه (OnInit)                                   |
//| این تابع هنگام شروع اکسپرت اجرا شده و تنظیمات اولیه را اعمال می‌کند.
//| - تنظیم ظاهر چارت (غیرفعال کردن گرید، تنظیم رنگ‌ها)
//| - اعتبارسنجی پارامترهای ورودی
//| - راه‌اندازی کتابخانه HipoFibonacci و اندیکاتورها
//+------------------------------------------------------------------+

int OnInit() {
   // غیرفعال کردن خطوط گرید چارت برای سادگی بصری
   ChartSetInteger(ChartID(), CHART_SHOW_GRID, false);
   
   // تنظیم رنگ پس‌زمینه و کندل‌ها برای ظاهر حرفه‌ای
   ChartSetInteger(ChartID(), CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BULL, clrGreen);
   ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BEAR, clrRed);
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_UP, clrGreen);
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_DOWN, clrRed);

   // اعتبارسنجی پارامترهای ورودی
   if(Risk_Percentage_Per_Trade <= 0.0 || Risk_Percentage_Per_Trade > 5.0) {
      lastError = "درصد ریسک نامعتبر است (باید بین 0.1 و 5.0 باشد)";
      return INIT_PARAMETERS_INCORRECT;
   }
   if(Risk_Reward_Ratio <= 0.0 || Risk_Reward_Ratio > 5.0) {
      lastError = "نسبت ریسک به ریوارد نامعتبر است (باید بین 1.0 و 5.0 باشد)";
      return INIT_PARAMETERS_INCORRECT;
   }
   if(SL_Buffer_Pips < 0.0) {
      lastError = "فاصله استاپ لاس نمی‌تواند منفی باشد";
      return INIT_PARAMETERS_INCORRECT;
   }
   if(HTF_Fast_EMA <= 0 || HTF_Slow_EMA <= 0 || HTF_Signal_SMA <= 0 ||
      MTF_Fast_EMA <= 0 || MTF_Slow_EMA <= 0 || MTF_Signal_SMA <= 0) {
      lastError = "تنظیمات MACD نمی‌تواند صفر یا منفی باشد";
      return INIT_PARAMETERS_INCORRECT;
   }

   // تنظیم اولیه کتابخانه HipoFibonacci
   fiboSettings.CalculationTimeframe = PERIOD_CURRENT; // تایم‌فریم محاسبات
   fiboSettings.Enable_Drawing = true;                 // فعال‌سازی رسم سطوح
   fiboSettings.Enable_Logging = true;                 // فعال‌سازی لاگ
   fiboSettings.Enable_Status_Panel = true;            // فعال‌سازی پنل وضعیت
   fiboSettings.MaxCandles = 500;                      // حداکثر کندل‌ها برای تحلیل
   fiboSettings.MarginPips = 1.0;                      // حاشیه پیپ
   fiboSettings.DetectionMethod = METHOD_POWER_SWING;  // روش تشخیص پیش‌فرض
   fiboSettings.Lookback = 3;                          // بازه نگاه به عقب
   fiboSettings.AtrPeriod = 14;                        // دوره ATR
   fiboSettings.AtrMultiplier = 2.5;                   // ضریب ATR
   fiboSettings.EntryZone_LowerLevel = 50.0;           // سطح پایین ناحیه ورود
   fiboSettings.EntryZone_UpperLevel = 68.0;           // سطح بالا ناحیه ورود
   fiboSettings.MotherFibo_Color = clrGray;            // رنگ فیبوناچی مادر
   fiboSettings.IntermediateFibo_Color = clrLemonChiffon; // رنگ فیبوناچی میانی
   fiboSettings.BuyEntryFibo_Color = clrLightGreen;    // رنگ ناحیه ورود خرید
   fiboSettings.SellEntryFibo_Color = clrRed;          // رنگ ناحیه ورود فروش
   HipoFibo.Init(fiboSettings);                        // فراخوانی تابع راه‌اندازی

   // ایجاد هندل‌های اندیکاتور MACD
   macd_htf_handle = iMACD(_Symbol, HTF_Timeframe, HTF_Fast_EMA, HTF_Slow_EMA, HTF_Signal_SMA, PRICE_CLOSE);
   macd_mtf_handle = iMACD(_Symbol, MTF_Timeframe, MTF_Fast_EMA, MTF_Slow_EMA, MTF_Signal_SMA, PRICE_CLOSE);
   if(macd_htf_handle == INVALID_HANDLE || macd_mtf_handle == INVALID_HANDLE) {
      lastError = "خطا در ایجاد هندل‌های MACD";
      return INIT_FAILED;
   }

   // ایجاد اندیکاتورهای نمایشی روی چارت اگر فعال باشند
   if(Enable_MACD_Display) {
      CreateMACDDisplay(HTF_Timeframe, HTF_MACD_Color, HTF_Signal_Color, 0);
      CreateMACDDisplay(MTF_Timeframe, MTF_MACD_Color, MTF_Signal_Color, 1);
   }

   // ایجاد پنل رابط کاربری
   CreateTraderPanel();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| تابع آزادسازی منابع (OnDeinit)                                   |
//| این تابع هنگام بسته شدن اکسپرت اجرا شده و منابع را آزاد می‌کند.
//| - آزادسازی هندل‌ها و حذف اشیاء گرافیکی
//+------------------------------------------------------------------+

void OnDeinit(const int reason) {
   IndicatorRelease(macd_htf_handle);  // آزادسازی هندل MACD تایم‌فریم بالا
   IndicatorRelease(macd_mtf_handle);  // آزادسازی هندل MACD تایم‌فریم میانی
   ObjectDelete(0, "HipoTrader_Panel"); // حذف پنل رابط کاربری
   if(Enable_MACD_Display) {
      ObjectDelete(0, "HTF_MACD");     // حذف اندیکاتور HTF
      ObjectDelete(0, "MTF_MACD");     // حذف اندیکاتور MTF
   }
}

//+------------------------------------------------------------------+
//| تابع پردازش تیک (OnTick)                                         |
//| این تابع در هر تیک بازار اجرا شده و عملیات سریع را مدیریت می‌کند.
//| - بررسی محدودیت تعداد معاملات و ناحیه طلایی
//| - به‌روزرسانی رابط کاربری و اجرای معاملات
//+------------------------------------------------------------------+

void OnTick() {
   if(CountOpenTrades() >= Max_Open_Trades) return; // بررسی حداکثر معاملات
   if(HipoFibo.IsEntryZoneActive()) return;         // جلوگیری از پردازش در ناحیه طلایی
   UpdateTraderPanel();                             // به‌روزرسانی پنل
   if(PositionsTotal() > 0) return;                 // مدیریت معاملات باز
   ExecuteTradeIfReady();                           // اجرای معامله اگر شرایط فراهم باشد
}

//+------------------------------------------------------------------+
//| تابع تشخیص کندل جدید (OnNewBar)                                  |
//| این تابع بررسی می‌کند که آیا کندل جدیدی بسته شده است یا خیر.
//| - مقایسه زمان فعلی با زمان آخرین کندل
//+------------------------------------------------------------------+

bool OnNewBar() {
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentTime != lastBarTime) {
      lastBarTime = currentTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| تابع پردازش اصلی (CoreProcessing)                                |
//| این تابع منطق اصلی تحلیل و ارسال دستور به کتابخانه را اجرا می‌کند.
//| - دریافت داده‌های MACD و تحلیل سیگنال‌ها
//| - پردازش کندل جدید و به‌روزرسانی روند
//+------------------------------------------------------------------+

void CoreProcessing() {
   double htf_main[], htf_signal[], mtf_main[], mtf_signal[];
   if(CopyBuffer(macd_htf_handle, 0, 1, 2, htf_main) < 2 || CopyBuffer(macd_htf_handle, 1, 1, 2, htf_signal) < 2 ||
      CopyBuffer(macd_mtf_handle, 0, 1, 2, mtf_main) < 2 || CopyBuffer(macd_mtf_handle, 1, 1, 2, mtf_signal) < 2) {
      lastError = "خطا در کپی داده‌های MACD";
      return;
   }

   bool htf_buy_permission = (htf_main[1] > htf_signal[1]);
   bool htf_sell_permission = (htf_signal[1] > htf_main[1]);
   bool mtf_buy_trigger = (mtf_main[1] < 0);
   bool mtf_sell_trigger = (mtf_main[1] > 0);

   E_Trend newTrend = NEUTRAL;
   if(htf_buy_permission && mtf_buy_trigger && !Enable_Confirmation_Filter) newTrend = TREND_UP;
   else if(htf_sell_permission && mtf_sell_trigger && !Enable_Confirmation_Filter) newTrend = TREND_DOWN;
   else if(Enable_Confirmation_Filter) {
      if(OnNewBar() && htf_buy_permission && mtf_buy_trigger) newTrend = TREND_UP;
      else if(OnNewBar() && htf_sell_permission && mtf_sell_trigger) newTrend = TREND_DOWN;
   }

   if(newTrend != currentTrend) {
      currentTrend = newTrend;
      E_SignalType signal = STOP_SEARCH;
      if(newTrend == TREND_UP) signal = SIGNAL_BUY;
      else if(newTrend == TREND_DOWN) signal = SIGNAL_SELL;
      HipoFibo.ReceiveCommand(signal, PERIOD_CURRENT);
   }

   if(OnNewBar()) {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2) {
         lastError = "خطا در کپی داده‌های قیمت";
         return;
      }
      datetime times[2] = {rates[0].time, rates[1].time};
      double opens[2] = {rates[0].open, rates[1].open};
      double highs[2] = {rates[0].high, rates[1].high};
      double lows[2] = {rates[0].low, rates[1].low};
      double closes[2] = {rates[0].close, rates[1].close};
      HipoFibo.OnNewCandle(2, times, opens, highs, lows, closes);
   }
}

//+------------------------------------------------------------------+
//| تابع اجرای معامله (ExecuteTrade)                                 |
//| این تابع زمانی فراخوانی می‌شود که ناحیه طلایی فعال باشد.
//| - محاسبه استاپ لاس، حجم، و حد سود
//| - ارسال سفارش با استفاده از CTrade
//+------------------------------------------------------------------+

void ExecuteTrade() {
   if(CountOpenTradesInZone() > 0) return;

   double sl_price = 0.0;
   if(!HipoFibo.GetFiboLevelPrice(FIBO_MOTHER, 0.0, sl_price)) {
      lastError = "خطا در دریافت قیمت استاپ لاس از کتابخانه";
      return;
   }

   double entry_price = 0.0;
   if(currentTrend == TREND_UP) {
      if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, entry_price)) {
         lastError = "خطا در دریافت قیمت ASK";
         return;
      }
   } else if(currentTrend == TREND_DOWN) {
      if(!SymbolInfoDouble(_Symbol, SYMBOL_BID, entry_price)) {
         lastError = "خطا در دریافت قیمت BID";
         return;
      }
   }

   double spread = 0.0;
   if(!SymbolInfoDouble(_Symbol, SYMBOL_SPREAD, spread)) spread = 0.0;
   spread *= _Point;
   double final_sl_price = (currentTrend == TREND_UP) ? sl_price - SL_Buffer_Pips * _Point - spread : sl_price + SL_Buffer_Pips * _Point + spread;
   double sl_distance = MathAbs(entry_price - final_sl_price) / _Point;

   double tick_value = 0.0;
   if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE, tick_value)) tick_value = 1.0;
   double volume = (AccountInfoDouble(ACCOUNT_BALANCE) * Risk_Percentage_Per_Trade / 100.0) / (sl_distance * tick_value);
   volume = NormalizeDouble(volume, 2);

   double tp_distance = sl_distance * Risk_Reward_Ratio;
   double take_profit = (currentTrend == TREND_UP) ? entry_price + tp_distance * _Point + spread : entry_price - tp_distance * _Point - spread;

   if(currentTrend == TREND_UP) {
      if(!trade.Buy(volume, _Symbol, entry_price, final_sl_price, take_profit, "Buy Order - HipoTrader")) {
         lastError = "خطا در ارسال سفارش خرید: " + IntegerToString(GetLastError());
      }
   } else if(currentTrend == TREND_DOWN) {
      if(!trade.Sell(volume, _Symbol, entry_price, final_sl_price, take_profit, "Sell Order - HipoTrader")) {
         lastError = "خطا در ارسال سفارش فروش: " + IntegerToString(GetLastError());
      }
   }

   if(trade.ResultRetcode() == TRADE_RETCODE_DONE) {
      HipoFibo.ReceiveCommand(STOP_SEARCH, PERIOD_CURRENT);
      Print("معامله با موفقیت اجرا شد - حجم: ", volume, "، SL: ", final_sl_price, "، TP: ", take_profit);
   }
}

//+------------------------------------------------------------------+
//| تابع اجرای معامله در صورت آمادگی (ExecuteTradeIfReady)           |
//| این تابع بررسی می‌کند که آیا شرایط ورود به معامله فراهم است یا خیر.
//+------------------------------------------------------------------+

void ExecuteTradeIfReady() {
   if(HipoFibo.IsEntryZoneActive()) ExecuteTrade();
}

//+------------------------------------------------------------------+
//| تابع شمارش معاملات باز (CountOpenTrades)                         |
//| این تابع تعداد معاملات باز با MagicNumber مشخص را محاسبه می‌کند.
//+------------------------------------------------------------------+

int CountOpenTrades() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| تابع شمارش معاملات در ناحیه طلایی (CountOpenTradesInZone)       |
//| این تابع تعداد معاملات باز در ناحیه طلایی فعلی را بررسی می‌کند.
//+------------------------------------------------------------------+

int CountOpenTradesInZone() {
   if(!HipoFibo.IsEntryZoneActive()) return 0;
   datetime zoneTime = HipoFibo.GetEntryZoneActivationTime();
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetInteger(POSITION_TIME) >= zoneTime) {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| تابع ایجاد اندیکاتور نمایشی (CreateMACDDisplay)                  |
//| این تابع اندیکاتور MACD را برای نمایش روی چارت ایجاد می‌کند.
//| - ایجاد ویندوهای جداگانه برای HTF و MTF
//+------------------------------------------------------------------+

void CreateMACDDisplay(ENUM_TIMEFRAMES timeframe, color macdColor, color signalColor, int subwindow) {
   string name = (subwindow == 0) ? "HTF_MACD" : "MTF_MACD";
   int handle = iMACD(_Symbol, timeframe, HTF_Fast_EMA, HTF_Slow_EMA, HTF_Signal_SMA, PRICE_CLOSE);
   if(handle != INVALID_HANDLE) {
      IndicatorSetInteger(INDICATOR_DIGITS, 5);
      IndicatorSetString(INDICATOR_SHORTNAME, name);
      if(subwindow > 0) ChartIndicatorAdd(ChartID(), subwindow, handle);
      IndicatorRelease(handle);
   }
}

//+------------------------------------------------------------------+
//| تابع ایجاد پنل رابط کاربری (CreateTraderPanel)                   |
//| این تابع پنل وضعیت اکسپرت را روی چارت ایجاد می‌کند.
//| - قرارگیری زیر پنل HipoFibonacci
//+------------------------------------------------------------------+

void CreateTraderPanel() {
   ObjectCreate(0, "HipoTrader_Panel", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "HipoTrader_Panel", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "HipoTrader_Panel", OBJPROP_YDISTANCE, 70);
   ObjectSetInteger(0, "HipoTrader_Panel", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "HipoTrader_Panel", OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, "HipoTrader_Panel", OBJPROP_FONT, "Arial");
   UpdateTraderPanel();
}

//+------------------------------------------------------------------+
//| تابع به‌روزرسانی پنل رابط کاربری (UpdateTraderPanel)            |
//| این تابع اطلاعات پنل را به‌روز می‌کند.
//| - نمایش وضعیت سیگنال‌ها، کتابخانه، و وضعیت کلی
//+------------------------------------------------------------------+

void UpdateTraderPanel() {
   string statusText = "HipoTrader Panel\n";
   color htfColor = (currentTrend == TREND_UP) ? clrGreen : (currentTrend == TREND_DOWN) ? clrRed : clrGray;
   statusText += "HTF Signal (H1): " + CharToString(110) + " [رنگ: " + GetColorName(htfColor) + "]\n";
   color mtfColor = (currentTrend == TREND_UP && HipoFibo.GetCurrentStatus() == ENTRY_ZONE_ACTIVE) ? clrGreen : 
                    (currentTrend == TREND_DOWN && HipoFibo.GetCurrentStatus() == ENTRY_ZONE_ACTIVE) ? clrRed : clrGray;
   statusText += "MTF Signal (M15): " + CharToString(110) + " [رنگ: " + GetColorName(mtfColor) + "]\n";
   string fiboStatus = EnumToString(HipoFibo.GetCurrentStatus());
   statusText += "HipoFibo Status: " + fiboStatus + "\n";
   string overallStatus = (HipoFibo.IsEntryZoneActive()) ? "در انتظار ورود..." : 
                         (PositionsTotal() > 0) ? "معامله باز..." : "جستجوی سیگنال...";
   statusText += "وضعیت کلی: " + overallStatus;

   ObjectSetString(0, "HipoTrader_Panel", OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, "HipoTrader_Panel", OBJPROP_COLOR, clrWhite);
}

//+------------------------------------------------------------------+
//| تابع تبدیل رنگ به نام (GetColorName)                             |
//| این تابع رنگ را به نام متنی تبدیل می‌کند.
//| - استفاده برای نمایش رنگ‌ها در پنل
//+------------------------------------------------------------------+

string GetColorName(color clr) {
   if(clr == clrGreen) return "سبز";
   if(clr == clrRed) return "قرمز";
   return "خاکستری";
}
