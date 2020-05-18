//+------------------------------------------------------------------+
//|                                                    HMA_Trend.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers   6
#property indicator_plots     3
#property indicator_type1     DRAW_LINE
#property indicator_type2     DRAW_LINE
#property indicator_type3     DRAW_LINE
#property indicator_style1    STYLE_SOLID
#property indicator_style2    STYLE_SOLID
#property indicator_style3    STYLE_SOLID
#property indicator_color1    clrYellow
#property indicator_color2    clrLime
#property indicator_color3    clrRed
#property indicator_width1    2
#property indicator_width2    2
#property indicator_width3    2
#property indicator_label1    "HullMA"
#property indicator_label2    "HullMA UpTrend"
#property indicator_label3    "HullMA DnTrend"

#include <MovingAverages.mqh>

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
input ENUM_APPLIED_PRICE Price = PRICE_CLOSE;
input int HMA_Period = 50;


double m_Buffer[];
double m_UpTrend[];
double m_DnTrend[];
double m_Ind_buffer1[];
double m_fLwmaBuffer[];
double m_sLwmaBuffer[];

int draw_begin0;
int fLwmaHandle;
int sLwmaHandle;

int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, m_Buffer);
   SetIndexBuffer(1, m_UpTrend);
   SetIndexBuffer(2, m_DnTrend);
   SetIndexBuffer(3, m_Ind_buffer1);
   
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0);
   draw_begin0 = (int)(HMA_Period+MathFloor(MathSqrt(HMA_Period)));
   IndicatorSetString(INDICATOR_SHORTNAME, "HMA("+IntegerToString(HMA_Period)+")");
   IndicatorSetInteger(INDICATOR_DIGITS, int(SymbolInfoInteger(Symbol(), SYMBOL_DIGITS) + 1));
   fLwmaHandle = iMA(Symbol(), Period(), int(MathFloor(HMA_Period/2)), 0, MODE_LWMA, Price);
   if(fLwmaHandle==INVALID_HANDLE) 
   { 
      PrintFormat("Failed to create handle of the first iMA indicator for the symbol %s/%s, error code %d", 
                  Symbol(), 
                  EnumToString(Period()), 
                  GetLastError()); 
      return(INIT_FAILED); 
   } 
   sLwmaHandle = iMA(Symbol(), Period(), HMA_Period, 0, MODE_LWMA, Price);
   if(sLwmaHandle==INVALID_HANDLE) 
   { 
      PrintFormat("Failed to create handle of the second iMA indicator for the symbol %s/%s, error code %d", 
                  Symbol(), 
                  EnumToString(Period()), 
                  GetLastError()); 
      return(INIT_FAILED); 
   } 
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(!FillArrayFromBuffer(m_fLwmaBuffer,0,fLwmaHandle,rates_total)) return(0);
   if(!FillArrayFromBuffer(m_sLwmaBuffer,0,sLwmaHandle,rates_total)) return(0);

   if (prev_calculated == 0)
   {
      for (int i = 0; i < draw_begin0; i++) m_Buffer[i] = 0;
      for (int i = 0; i < HMA_Period; i++) m_Ind_buffer1[i] = 0;
   }
   int start = prev_calculated;
   if (start != 0 ) start -= 1;
   
   for (int i = start; i < rates_total; i++)
   {
      m_Ind_buffer1[i] = 2.0 * m_fLwmaBuffer[i] - m_sLwmaBuffer[i];
   }
   
   for (int i = start; i < rates_total; i++)
   {
      m_Buffer[i] = LinearWeightedMA(i, (int)MathFloor(MathSqrt(HMA_Period)), m_Ind_buffer1);
      if (i == 0) continue;
      if (m_Buffer[i] - m_Buffer[i - 1] > 0)
      {
         m_UpTrend[i] = m_Buffer[i];
         m_DnTrend[i] = 0;
      }
      if (m_Buffer[i - 1] - m_Buffer[i] > 0)
      {
         m_DnTrend[i] = m_Buffer[i];
         m_UpTrend[i] = 0;
      }
   }
   
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+

bool FillArrayFromBuffer(double &values[],   // indicator buffer of Moving Average values 
                         int shift,          // shift 
                         int ind_handle,     // handle of the iMA indicator 
                         int amount          // number of copied values 
                         ) 
  { 
//--- reset error code 
   ResetLastError(); 
//--- fill a part of the iMABuffer array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(ind_handle,0,-shift,amount,values)<0) 
     { 
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iMA indicator, error code %d",GetLastError()); 
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(false); 
     } 
//--- everything is fine 
   return(true); 
  }
  
void OnDeinit(const int reason) 
  { 
   if(fLwmaHandle!=INVALID_HANDLE) 
      IndicatorRelease(fLwmaHandle); 
   if(sLwmaHandle!=INVALID_HANDLE) 
      IndicatorRelease(sLwmaHandle); 
//--- clear the chart after deleting the indicator 
   Comment(""); 
  }     