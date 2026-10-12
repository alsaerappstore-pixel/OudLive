#include "../OudLive/Audio/DSP.hpp"
#include <cassert>
#include <iostream>
#include <vector>
std::vector<float> render(float wet,float dry,float rate){
 oud::Controls p=oud::defaults;p[oud::Reverb]=.3f;p[oud::ReverbWet]=wet;p[oud::ReverbDry]=dry;p[oud::Noise]=p[oud::Compression]=p[oud::Makeup]=p[oud::Trim]=0;
 oud::AcousticState s;s.prepare(rate,p);std::vector<float> out(size_t(rate*2));
 for(size_t i=0;i<out.size();++i)out[i]=s.tick(i==0?.1f:0)[0];return out;
}
int main(){
 for(float rate:{8000.f,16000.f,44100.f,48000.f,96000.f}){
  auto d=render(0,1,rate),w=render(1,0,rate),m=render(.4f,.7f,rate),z=render(0,0,rate);
  double tail=0;assert(std::abs(d[0])>.001f);
  for(size_t i=0;i<m.size();++i){assert(std::isfinite(m[i]));assert(std::abs(m[i]-(.7f*d[i]+.4f*w[i]))<1e-6f);assert(z[i]==0);if(i<size_t(rate*.024))assert(w[i]==0);if(i>size_t(rate*.1))tail+=w[i]*w[i];}
  assert(tail>1e-8);
 }
 oud::DSP s;s.set(oud::Input,0);s.set(oud::Output,0);s.set(oud::ReverbDry,0);s.set(oud::ReverbWet,0);s.prepare(48000);
 std::vector<float> in(48000,.01f),l(48000),r(48000),rl(48000),rr(48000);
 s.process(in.data(),l.data(),r.data(),in.size(),rl.data(),rr.data());assert(rl.back()==0 && l.back()==0);
 s.set(oud::ReverbDry,1);s.set(oud::ReverbWet,1);s.process(in.data(),l.data(),r.data(),in.size(),rl.data(),rr.data());
 for(size_t i=0;i<l.size();++i){assert(std::isfinite(l[i]));assert(std::abs(l[i])<=.981f);if(i>10000)assert(std::abs(l[i]-rl[i])<1e-6);if(i>0)assert(std::abs(l[i]-l[i-1])<.01f);}
 std::cout<<"PASS independent wet/dry gain, zero mix silence, pre-delay, reverb tail, sample rates, smooth live/record changes\n";
}
