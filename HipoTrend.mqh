//+------------------------------------------------------------------+
//|                                                    HipoTrend.mqh  |
//|                              محصولی از: Hipo Algorithm           |
//|                              نسخه: ۱.۰.۱                          |
//|                              تاریخ: ۲۰۲۵/۰۸/۰۲                   |
//| کتابخانه تشخیص روند بازار برای متاتریدر ۵                      |
//+------------------------------------------------------------------+

#property copyright "Hipo Algorithm"
#property link      "https://hipoalgorithm.com"
#property version   "1.0.1"

#ifndef __HIPO_TREND_MQH__
#define __HIPO_TREND_MQH__

//+------------------------------------------------------------------+
//| تعاریف و ثابت‌ها                                                |
//+------------------------------------------------------------------+
enum ENUM_MACD_Multiplier
{
   QUARTER_X,  // ضریب ۰.۲۵
   HALF_X,     // ضریب ۰.۵
   ONE_X,      // ضریب ۱.۰
   TWO_X,      // ضریب ۲.۰
   FOUR_X,     // ضریب ۴.۰
   EIGHT_X     // ضریب ۸.۰
};

enum ENUM_DIRECTION
{
   LONG,    // خرید
   SHORT,   // فروش
   NEUTRAL  // خنثی (نامشخص)
};

//+------------------------------------------------------------------+
//| کلاس CHipoTrend: تشخیص روند بازار                               |
//+------------------------------------------------------------------+
class CHipoTrend
{
private:
   ENUM_TIMEFRAMES       m_timeframe;      // تایم‌فریم برای تحلیل روند
   ENUM_MACD_Multiplier  m_multiplier;     // ضریب تنظیم دوره‌های MACD
   int                   m_macd_handle;    // هندل اندیکاتور MACD

   //+-------------------------------------------------------------+
   //| دریافت ضریب عددی از ENUM_MACD_Multiplier                   |
   //+-------------------------------------------------------------+
   double GetMultiplierFactor(ENUM_MACD_Multiplier multiplier)
   {
      switch(multiplier)
      {
         case QUARTER_X: return 0.25;
         case HALF_X:    return 0.5;
         case ONE_X:     return 1.0;
         case TWO_X:     return 2.0;
         case FOUR_X:    return 4.0;
         case EIGHT_X:   return 8.0;
         default:        return 1.0;
      }
   }

public:
   //+-------------------------------------------------------------+
   //| سازنده کلاس                                                |
   //+-------------------------------------------------------------+
   CHipoTrend(ENUM_TIMEFRAMES timeframe, ENUM_MACD_Multiplier multiplier)
   {
      m_timeframe = timeframe;
      m_multiplier = multiplier;
      double factor = GetMultiplierFactor(multiplier);
      int fast_ema = (int)MathRound(12 * factor);    // دوره سریع EMA
      int slow_ema = (int)MathRound(26 * factor);    // دوره کند EMA
      int signal_sma = (int)MathRound(9 * factor);   // دوره سیگنال SMA
      m_macd_handle = iMACD(_Symbol, m_timeframe, fast_ema, slow_ema, signal_sma, PRICE_CLOSE);
      if(m_macd_handle == INVALID_HANDLE)
      {
         Print("خطا: ایجاد هندل MACD ناموفق بود");
      }
   }

   //+-------------------------------------------------------------+
   //| تخریب‌کننده کلاس                                           |
   //+-------------------------------------------------------------+
   ~CHipoTrend()
   {
      if(m_macd_handle != INVALID_HANDLE)
         IndicatorRelease(m_macd_handle);
   }

   //+-------------------------------------------------------------+
   //| دریافت جهت روند بازار                                      |
   //+-------------------------------------------------------------+
   ENUM_DIRECTION GetTrendDirection()
   {
      if(m_macd_handle == INVALID_HANDLE)
      {
         Print("خطا: هندل MACD نامعتبر است");
         return NEUTRAL; // بازگشت خنثی در صورت خطا
      }
      double macd[], signal[];
      ArraySetAsSeries(macd, true);
      ArraySetAsSeries(signal, true);
      // دریافت مقادیر MACD و سیگنال برای کندل قبلی (بار ۱)
      if(CopyBuffer(m_macd_handle, 0, 1, 1, macd) < 1 || CopyBuffer(m_macd_handle, 1, 1, 1, signal) < 1)
      {
         Print("خطا: دریافت داده‌های MACD ناموفق بود");
         return NEUTRAL; // بازگشت خنثی در صورت خطا
      }
      // مقایسه خط MACD و سیگنال
      if(macd[0] > signal[0]) return LONG;
      if(macd[0] < signal[0]) return SHORT;
      return NEUTRAL; // در صورت برابر بودن MACD و سیگنال
   }
};

#endif // __HIPO_TREND_MQH__
