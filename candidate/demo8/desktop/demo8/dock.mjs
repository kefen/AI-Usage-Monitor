export const edges=['left','right','top','bottom'];
export function nearestEdge(a,p){
  const d=[Math.abs(p.x-a.x),Math.abs(a.x+a.width-p.x),Math.abs(p.y-a.y),Math.abs(a.y+a.height-p.y)];
  return edges[d.indexOf(Math.min(...d))];
}
export function dockBounds(a,edge,open,height=540,anchor=.5){
  const vertical=edge==='left'||edge==='right';
  const width=Math.min(a.width,vertical?(open?228:6):(open?1152:56));
  const h=Math.min(a.height,open?height:vertical?56:6);
  const along=(span,size)=>Math.max(0,Math.min(span-size,Math.floor(span*anchor-size/2)));
  return {width,height:h,x:a.x+(edge==='left'?0:edge==='right'?a.width-width:along(a.width,width)),
    y:a.y+(edge==='top'?0:edge==='bottom'?a.height-h:along(a.height,h))};
}
export function contains(b,p){return p.x>=b.x&&p.x<b.x+b.width&&p.y>=b.y&&p.y<b.y+b.height;}
export function liveWindow(window){
  return Boolean(window && !window.isDestroyed());
}

export function dockVisible(rail,indicator){
  return liveWindow(rail) && (rail.isVisible() || (liveWindow(indicator) && indicator.isVisible()));
}
