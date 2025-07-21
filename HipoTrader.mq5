//+------------------------------------------------------------------+
//| HipoTrader.mq5                                                  |
//| Copyright © 2025 HipoAlgorithm                                   |
//| https://hipoalgorithm.com                                        |
//| نسخه: 2.3                                                        |
//| توضیحات: این اکسپرت با استفاده از اندیکاتور MACD در دو تایم‌فریم (HTF و MTF)، جهت بازار را تشخیص داده و با کتابخانه HipoFibonacci (نسخه 2.4) نقاط ورود بهینه را محاسبه می‌کند. مدیریت ریسک و ورود به معامله بهبود یافته است. |
//| هماهنگی: این کد با نسخه 2.4 کتابخانه HipoFibonacci.mqh طراحی شده است. |
//+------------------------------------------------------------------+

#property copyright "HipoAlgorithm"
#property link      "https://hipoalgorithm.com"
#property version   "2.3"
#property strict

// شامل کردن کتابخانه‌های مورد نیاز
#include <HipoFibonacci.mqh>
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| متغیرهای سراسری                                                 |
//| این بخش شامل متغیرهای اصلی اکسپرت است که در کل برنامه استفاده می‌شوند. |
//+------------------------------------------------------------------+

CHipoFibonacci HipoFibo;                // نمونه از کلاس CHipoFibonacci برای مدیریت فیبوناچی
CTrade trade;                           // کلاس استاندارد متاتریدر برای مدیریت معاملات
int macd_htf_handle;                    // هندل برای اندیکاتور MACD در تایم‌فریم بالا
int macd_mtf_handle;                    // هندل برای اندیکاتور MACD در تایم‌فریم میانی
enum E_Trend { TREND_UP, TREND_DOWN, NEUTRAL }; // تعریف انوم برای وضعیت روند
E_Trend currentTrend = NEUTRAL;         // وضعیت فعلی روند بازار
bool isCommandSent = false;             // وضعیت ارسال دستور به کتابخانه (قفل)
HipoSettings fiboSettings;              // ساختار تنظیمات کتابخانه HipoFibonacci
datetime lastBarTime = 0;               // زمان آخرین کندل پردازش‌شده
string lastError = "";                  // ذخیره آخرین خطا برای گزارش‌دهی
datetime lastTradeTime = 0;             // زمان آخرین معامله برای جلوگیری از ورود تند تند

//+------------------------------------------------------------------+
//| پارامترهای ورودی                                                 |
//| این بخش شامل تنظیمات قابل تغییر توسط کاربر است که به صورت گروه‌بندی شده تعریف شده‌اند. |
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

input group "تنظیمات کتابخانه HipoFibonacci"
input int HipoFibo_KingPeakLookback = 100; // بازه نگاه به عقب برای قله/دره پادشاه
input double HipoFibo_EntryZone_LowerLevel = 50.0; // سطح پایین ناحیه ورود
input double HipoFibo_EntryZone_UpperLevel = 68.0; // سطح بالا ناحیه ورود
input color HipoFibo_MotherFibo_Color = clrGray; // رنگ فیبوناچی مادر
input color HipoFibo_IntermediateFibo_Color = clrLemonChiffon; // رنگ فیبوناچی میانی
input color HipoFibo_BuyEntryFibo_Color = clrLightGreen; // رنگ ناحیه ورود خرید
input color HipoFibo_SellEntryFibo_Color = clrRed; // رنگ ناحیه ورود فروش

//+------------------------------------------------------------------+
//| تابع راه‌اندازی اولیه (OnInit)                                   |
//| این تابع هنگام شروع اکسپرت اجرا شده و تنظیمات اولیه را اعمال می‌کند. |
//+------------------------------------------------------------------+

int OnInit() {
   // غیرفعال کردن خطوط گرید چارت برای سادگی بصری
   if(!ChartSetInteger(ChartID(), CHART_SHOW_GRID, false)) {
      lastError = "خطا در غیرفعال کردن گرید چارت";
      return INIT_FAILED;
   }

   // تنظیم رنگ‌های چارت برای ظاهر حرفه‌ای
   if(!ChartSetInteger(ChartID(), CHART_COLOR_BACKGROUND, clrBlack) ||
      !ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BULL, clrGreen) ||
      !ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BEAR, clrRed) ||
      !ChartSetInteger(ChartID(), CHART_COLOR_CHART_UP, clrGreen) ||
      !ChartSetInteger(ChartID(), CHART_COLOR_CHART_DOWN, clrRed)) {
      lastError = "خطا در تنظیم رنگ‌های چارت";
      return INIT_FAILED;
   }

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
   if(HipoFibo_KingPeakLookback <= 0) {
      lastError = "تنظیمات KingPeakLookback نمی‌تواند صفر یا منفی باشد";
      return INIT_PARAMETERS_INCORRECT;
   }
   if(HipoFibo_EntryZone_LowerLevel >= HipoFibo_EntryZone_UpperLevel) {
      lastError = "سطح پایین ناحیه ورود باید کمتر از سطح بالا باشد";
      return INIT_PARAMETERS_INCORRECT;
   }

   // تنظیم اولیه کتابخانه HipoFibonacci با ورودی‌های کاربر
   fiboSettings.CalculationTimeframe = PERIOD_CURRENT;
   fiboSettings.Enable_Drawing = true;
   fiboSettings.Enable_Logging = true;
   fiboSettings.Enable_Status_Panel = true;
   fiboSettings.MaxCandles = 500;
   fiboSettings.MarginPips = 1.0;
   fiboSettings.KingPeakLookback = HipoFibo_KingPeakLookback;
   fiboSettings.EntryZone_LowerLevel = HipoFibo_EntryZone_LowerLevel;
   fiboSettings.EntryZone_UpperLevel = HipoFibo_EntryZone_UpperLevel;
   fiboSettings.MotherFibo_Color = HipoFibo_MotherFibo_Color;
   fiboSettings.IntermediateFibo_Color = HipoFibo_IntermediateFibo_Color;
   fiboSettings.BuyEntryFibo_Color = HipoFibo_BuyEntryFibo_Color;
   fiboSettings.SellEntryFibo_Color = HipoFibo_SellEntryFibo_Color;
   HipoFibo.Init(fiboSettings);

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

   // فعال‌سازی تایمر برای اجرای منطق اصلی هر ثانیه
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| تابع آزادسازی منابع (OnDeinit)                                   |
//| این تابع هنگام بسته شدن اکسپرت اجرا شده و منابع را آزاد می‌کند. |
//+------------------------------------------------------------------+

void OnDeinit(const int reason) {
   if(macd_htf_handle != INVALID_HANDLE) IndicatorRelease(macd_htf_handle);
   if(macd_mtf_handle != INVALID_HANDLE) IndicatorRelease(macd_mtf_handle);
   ObjectDelete(0, "HipoTrader_Panel_BG");
   ObjectDelete(0, "HipoTrader_Panel_Trend_Bullet");
   ObjectDelete(0, "HipoTrader_Panel_Trend_Text");
   ObjectDelete(0, "HipoTrader_Panel_HTF_Bullet");
   ObjectDelete(0, "HipoTrader_Panel_HTF_Text");
   ObjectDelete(0, "HipoTrader_Panel_MTF_Bullet");
   ObjectDelete(0, "HipoTrader_Panel_MTF_Text");
   ObjectDelete(0, "HipoTrader_Panel_Fibo_Bullet");
   ObjectDelete(0, "HipoTrader_Panel_Fibo_Text");
   ObjectDelete(0, "HipoTrader_Panel_Status_Bullet");
   ObjectDelete(0, "HipoTrader_Panel_Status_Text");
   if(Enable_MACD_Display) {
      ObjectDelete(0, "HTF_MACD");
      ObjectDelete(0, "MTF_MACD");
   }
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| تابع پردازش تیک (OnTick)                                         |
//| این تابع در هر تیک بازار اجرا شده و فقط عملیات سریع را مدیریت می‌کند. |
//+------------------------------------------------------------------+

void OnTick() {
   // خالی برای عملکرد بهینه
}

//+------------------------------------------------------------------+
//| تابع پردازش زمان‌بندی (نسخه نهایی با معماری صحیح)                 |
//| این تابع با ارسال صحیح داده‌ها به کتابخانه و بررسی پایدار روند، مشکل ناپایداری را حل می‌کند. |
//+------------------------------------------------------------------+

void OnTimer() {
   // بخش ۱: شنونده پاسخ - این بخش باید هر ثانیه اجرا بشه تا سریع واکنش بده
   if(isCommandSent && HipoFibo.GetCurrentStatus() == SEARCHING_FOR_LEG) {
      isCommandSent = false; // کتابخانه کارش تمام شده، قفل آزاد می‌شود
      Print("کتابخانه ساختار قبلی را تمام کرده. اکسپرت آماده ارسال دستور جدید است.");
   }

   // بخش ۲: منطق اصلی - این بخش فقط باید روی کندل جدید اجرا بشه تا سیگنال پایدار باشه
   if(OnNewBar()) {
      // اول روند را بر اساس کندل بسته شده تشخیص بده
      CoreProcessing();
      
      // سپس داده‌های جدید را به کتابخانه ارسال کن
      int bars_to_copy = fiboSettings.KingPeakLookback + 5;
      MqlRates rates[];
      
      ArraySetAsSeries(rates, true);
      
      if(CopyRates(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, rates) >= bars_to_copy) {
         HipoFibo.OnNewCandle(rates);
      } else {
         lastError = "تعداد کندل‌های کافی در تاریخچه برای تحلیل وجود ندارد.";
         Print(lastError);
      }
   }
   
   // بخش ۳: آپدیت پنل و بررسی ورود - اینها می‌توانند هر ثانیه اجرا شوند
   UpdateTraderPanel();
   ExecuteTradeIfReady();
}

//+------------------------------------------------------------------+
//| تابع تشخیص کندل جدید (OnNewBar)                                  |
//| این تابع بررسی می‌کند که آیا کندل جدیدی بسته شده است یا خیر.    |
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
//| تابع پردازش اصلی (نسخه جدید با منطق درخواست/پاسخ و کنترل ورود)   |
//| این تابع منطق اصلی تحلیل و ارسال دستور به کتابخانه را اجرا می‌کند. |
//+------------------------------------------------------------------+

void CoreProcessing() {
   double htf_main[], htf_signal[], mtf_main[], mtf_signal[];
   if(CopyBuffer(macd_htf_handle, 0, 1, 2, htf_main) < 2 || 
      CopyBuffer(macd_htf_handle, 1, 1, 2, htf_signal) < 2 ||
      CopyBuffer(macd_mtf_handle, 0, 1, 2, mtf_main) < 2 || 
      CopyBuffer(macd_mtf_handle, 1, 1, 2, mtf_signal) < 2) {
      lastError = "خطا در کپی داده‌های MACD";
      return;
   }

   bool htf_buy_permission = (htf_main[0] > htf_signal[0]);
   bool htf_sell_permission = (htf_signal[0] > htf_main[0]);
   bool mtf_buy_trigger = (mtf_main[0] < 0);
   bool mtf_sell_trigger = (mtf_main[0] > 0);

   E_Trend newTrend = NEUTRAL;
   if(htf_buy_permission && mtf_buy_trigger && !Enable_Confirmation_Filter) newTrend = TREND_UP;
   else if(htf_sell_permission && mtf_sell_trigger && !Enable_Confirmation_Filter) newTrend = TREND_DOWN;
   else if(Enable_Confirmation_Filter) {
      if(OnNewBar() && htf_buy_permission && mtf_buy_trigger) newTrend = TREND_UP;
      else if(OnNewBar() && htf_sell_permission && mtf_sell_trigger) newTrend = TREND_DOWN;
   }

   // چک وضعیت فعلی کتابخونه
   E_Status currentStatus = HipoFibo.GetCurrentStatus();

   // شرط توقف بر اساس تغییر HTF
   if((newTrend != currentTrend && isCommandSent) || (newTrend == NEUTRAL && isCommandSent)) {
      currentTrend = newTrend;
      HipoFibo.ReceiveCommand(STOP_SEARCH, PERIOD_CURRENT);
      isCommandSent = false;
      Print("روند در اکسپرت تغییر کرد یا خنثی شد. دستور توقف به کتابخانه ارسال شد.");
      return;
   }

   // ارسال سیگنال جدید فقط اگر قبلاً دستوری ارسال نشده باشه و معامله باز نباشه
   if(newTrend != NEUTRAL && !isCommandSent && CountOpenTrades() == 0) {
      currentTrend = newTrend;
      if(newTrend == TREND_UP) {
         HipoFibo.ReceiveCommand(SIGNAL_BUY, PERIOD_CURRENT);
         isCommandSent = true;
         Print("دستور خرید جدید صادر شد. اکسپرت در حالت انتظار.");
      } else if(newTrend == TREND_DOWN) {
         HipoFibo.ReceiveCommand(SIGNAL_SELL, PERIOD_CURRENT);
         isCommandSent = true;
         Print("دستور فروش جدید صادر شد. اکسپرت در حالت انتظار.");
      }
   }
}

//+------------------------------------------------------------------+
//| تابع اجرای معامله (ExecuteTrade)                                 |
//| این تابع زمانی فراخوانی می‌شود که ناحیه طلایی فعال باشد.        |
//+------------------------------------------------------------------+

void ExecuteTrade() {
   if(CountOpenTradesInZone() > 0 || TimeCurrent() - lastTradeTime < 60) return; // جلوگیری از ورود تند تند (حداقل 60 ثانیه فاصله)

   double sl_price = HipoFibo.GetFiboLevelPrice(FIBO_MOTHER, 0.0);
   if(sl_price == 0.0) {
      lastError = "خطا در دریافت قیمت استاپ لاس از کتابخانه";
      return;
   }

   double entry_price = 0.0;
   if(currentTrend == TREND_UP) {
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry_price == 0.0) {
         lastError = "خطا در دریافت قیمت ASK";
         return;
      }
   } else if(currentTrend == TREND_DOWN) {
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry_price == 0.0) {
         lastError = "خطا در دریافت قیمت BID";
         return;
      }
   }

   long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spread = spread_points * _Point;

   double final_sl_price = (currentTrend == TREND_UP) ? sl_price - SL_Buffer_Pips * _Point - spread : sl_price + SL_Buffer_Pips * _Point + spread;
   double sl_distance = MathAbs(entry_price - final_sl_price) / _Point;

   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_value == 0.0) {
      lastError = "خطا در دریافت ارزش تیک";
      return;
   }
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

   // ثبت زمان معامله و آزادسازی قفل
   lastTradeTime = TimeCurrent();
   isCommandSent = false;

   if(trade.ResultRetcode() == TRADE_RETCODE_DONE) {
      Print("معامله با موفقیت اجرا شد - حجم: ", volume, "، SL: ", final_sl_price, "، TP: ", take_profit);
   } else {
      Print("تلاش برای ورود به معامله انجام شد اما با خطا مواجه شد: ", lastError);
   }
}

//+------------------------------------------------------------------+
//| تابع اجرای معامله در صورت آمادگی (ExecuteTradeIfReady)           |
//| این تابع بررسی می‌کند که آیا شرایط ورود به معامله فراهم است یا خیر. |
//+------------------------------------------------------------------+

void ExecuteTradeIfReady() {
   if(HipoFibo.IsEntryZoneActive() && CountOpenTrades() < Max_Open_Trades) ExecuteTrade();
}

//+------------------------------------------------------------------+
//| تابع شمارش معاملات باز (CountOpenTrades)                         |
//| این تابع تعداد معاملات باز با MagicNumber مشخص را محاسبه می‌کند. |
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
//| این تابع تعداد معاملات باز در ناحیه طلایی فعلی را بررسی می‌کند. |
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
//| این تابع اندیکاتور MACD را برای نمایش روی چارت ایجاد می‌کند.     |
//+------------------------------------------------------------------+

void CreateMACDDisplay(ENUM_TIMEFRAMES timeframe, color macdColor, color signalColor, int subwindow) {
   string name = (subwindow == 0) ? "HTF_MACD" : "MTF_MACD";
   int handle = iMACD(_Symbol, timeframe, HTF_Fast_EMA, HTF_Slow_EMA, HTF_Signal_SMA, PRICE_CLOSE);
   if(handle != INVALID_HANDLE) {
      IndicatorSetInteger(INDICATOR_DIGITS, 5);
      IndicatorSetString(INDICATOR_SHORTNAME, name);
      if(subwindow > 0) ChartIndicatorAdd(ChartID(), subwindow, handle);
   }
}

//+------------------------------------------------------------------+
//| تابع ایجاد پنل رابط کاربری (نسخه نهایی با لیبل‌های جدا)           |
//+------------------------------------------------------------------+
void CreateTraderPanel() {
    // ایجاد کادر پس‌زمینه
    ObjectCreate(0, "HipoTrader_Panel_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_YDISTANCE, 100);
    ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_XSIZE, 220);
    ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_YSIZE, 120); // کمی بزرگتر برای جا شدن متن
    ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_BGCOLOR, clrBlack);
    ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "HipoTrader_Panel_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);

    // ایجاد لیبل‌های جداگانه برای هر خط (یک لیبل برای دایره، یکی برای متن)
    string base_names[] = {"Trend", "HTF", "MTF", "Fibo", "Status"};
    int y_positions[] = {105, 125, 145, 165, 185};
   
    for(int i = 0; i < ArraySize(base_names); i++) {
        string bullet_name = "HipoTrader_Panel_" + base_names[i] + "_Bullet";
        string text_name = "HipoTrader_Panel_" + base_names[i] + "_Text";

        // ایجاد لیبل برای دایره رنگی
        ObjectCreate(0, bullet_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, bullet_name, OBJPROP_XDISTANCE, 15);
        ObjectSetInteger(0, bullet_name, OBJPROP_YDISTANCE, y_positions[i]);
        ObjectSetString(0, bullet_name, OBJPROP_TEXT, "●");
        ObjectSetInteger(0, bullet_name, OBJPROP_FONTSIZE, 12);
        ObjectSetString(0, bullet_name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, bullet_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);

        // ایجاد لیبل برای متن سفید
        ObjectCreate(0, text_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, text_name, OBJPROP_XDISTANCE, 30); // با کمی فاصله از دایره
        ObjectSetInteger(0, text_name, OBJPROP_YDISTANCE, y_positions[i]);
        ObjectSetString(0, text_name, OBJPROP_TEXT, "...");
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 10);
        ObjectSetString(0, text_name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, text_name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }
    UpdateTraderPanel();
}

//+------------------------------------------------------------------+
//| تابع به‌روزرسانی پنل رابط کاربری (نسخه نهایی با لیبل‌های جدا)    |
//+------------------------------------------------------------------+
void UpdateTraderPanel() {
    // --- خط ۱: روند کلی ---
    string trend_text = "روند: ";
    color trend_color = clrGray;
    switch(currentTrend) {
        case TREND_UP:   trend_text += "صعودی"; trend_color = clrGreen; break;
        case TREND_DOWN: trend_text += "نزولی"; trend_color = clrRed; break;
        case NEUTRAL:    trend_text += "خنثی"; break;
    }
    ObjectSetInteger(0, "HipoTrader_Panel_Trend_Bullet", OBJPROP_COLOR, trend_color);
    ObjectSetString(0, "HipoTrader_Panel_Trend_Text", OBJPROP_TEXT, trend_text);

    // --- خط ۲: HTF MACD ---
    string htf_text = "HTF MACD: ";
    color htf_color = clrGray;
    double htf_main[], htf_signal[];
    if(CopyBuffer(macd_htf_handle, 0, 1, 1, htf_main) >= 1 && CopyBuffer(macd_htf_handle, 1, 1, 1, htf_signal) >= 1) {
        bool is_up = htf_main[0] > htf_signal[0];
        htf_text += is_up ? "صعودی" : "نزولی";
        htf_color = is_up ? clrGreen : clrRed;
    } else { htf_text += "نامشخص"; }
    ObjectSetInteger(0, "HipoTrader_Panel_HTF_Bullet", OBJPROP_COLOR, htf_color);
    ObjectSetString(0, "HipoTrader_Panel_HTF_Text", OBJPROP_TEXT, htf_text);

    // --- خط ۳: MTF MACD ---
    string mtf_text = "MTF MACD: ";
    color mtf_color = clrGray;
    double mtf_main[];
    if(CopyBuffer(macd_mtf_handle, 0, 1, 1, mtf_main) >= 1) {
        bool is_up = mtf_main[0] < 0;
        mtf_text += is_up ? "صعودی" : "نزولی";
        mtf_color = is_up ? clrGreen : clrRed;
    } else { mtf_text += "نامشخص"; }
    ObjectSetInteger(0, "HipoTrader_Panel_MTF_Bullet", OBJPROP_COLOR, mtf_color);
    ObjectSetString(0, "HipoTrader_Panel_MTF_Text", OBJPROP_TEXT, mtf_text);

    // --- خط ۴: وضعیت HipoFibo ---
    string fibo_text = "HipoFibo: " + EnumToString(HipoFibo.GetCurrentStatus());
    color fibo_color = clrGray;
    E_Status fibo_status = HipoFibo.GetCurrentStatus();
    if(fibo_status == ENTRY_ZONE_ACTIVE) fibo_color = clrGreen;
    else if(fibo_status != SEARCHING_FOR_LEG && fibo_status != WAITING_FOR_COMMAND) fibo_color = clrYellow;
    ObjectSetInteger(0, "HipoTrader_Panel_Fibo_Bullet", OBJPROP_COLOR, fibo_color);
    ObjectSetString(0, "HipoTrader_Panel_Fibo_Text", OBJPROP_TEXT, fibo_text);

    // --- خط ۵: وضعیت کلی ---
    string status_text = "وضعیت: ";
    color status_color = clrGray;
    if(HipoFibo.IsEntryZoneActive()) {
        status_text += "ناحیه طلایی فعال";
        status_color = clrGreen;
    } else if(CountOpenTrades() > 0) {
        status_text += "معامله باز";
        status_color = clrDodgerBlue;
    } else {
        status_text += isCommandSent ? "در انتظار پاسخ کتابخانه" : "جستجوی سیگنال";
        status_color = isCommandSent ? clrYellow : clrGray;
    }
    ObjectSetInteger(0, "HipoTrader_Panel_Status_Bullet", OBJPROP_COLOR, status_color);
    ObjectSetString(0, "HipoTrader_Panel_Status_Text", OBJPROP_TEXT, status_text);
}

//+------------------------------------------------------------------+
//| تابع تبدیل رنگ به نام (GetColorName)                             |
//| این تابع رنگ را به نام متنی تبدیل می‌کند.                       |
//+------------------------------------------------------------------+

string GetColorName(color clr) {
   if(clr == clrGreen) return "سبز";
   if(clr == clrRed) return "قرمز";
   return "خاکستری";
}
