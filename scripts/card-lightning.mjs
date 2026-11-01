// Card.dc.html: M14 1L4 13.5h6.2L8.5 23L20 9.5h-6.4Z.
// Its 18px SVG viewport is halved with the 296px source card, hence 9/24.
const points=[[14,1],[4,13.5],[10.2,13.5],[8.5,23],[20,9.5],[13.6,9.5]]
  .map(([x,y])=>[(x-12)*9/24,(12-y)*9/24]);
const triangles=[[5,0,1],[5,1,2],[5,2,3],[3,4,5]];

export function cardLightning(picture,colour) {
  return triangles.map((indices,i)=>{
    const [apex,left,right]=indices.map(index=>points[index]);
    // Affine map of the native triangle (0,.5),(-.5,-.5),(.5,-.5).
    const a=right[0]-left[0],c=right[1]-left[1];
    const b=apex[0]-(left[0]+right[0])/2,d=apex[1]-(left[1]+right[1])/2;
    // A=R(theta) * scale(sx,sy) * R(-phi): native transforms only, no shear API.
    const phi=Math.atan2(2*(a*b+c*d),a*a+c*c-b*b-d*d)/2;
    const x=a*Math.cos(phi)+b*Math.sin(phi),y=c*Math.cos(phi)+d*Math.sin(phi);
    const sx=Math.hypot(x,y),sy=(a*d-b*c)/sx;
    return {name:'triangle'+(i+1),kind:'container',size:[1,1],
      position:[apex[0]-b/2,apex[1]-d/2],rotation:Math.atan2(y,x)*180/Math.PI,scale:[sx,sy],
      children:[{...picture('fill',[0,0,1,1],100003,colour),rotation:-phi*180/Math.PI}]};
  });
}
