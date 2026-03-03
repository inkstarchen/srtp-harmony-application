export function lerp(a:number , b:number, t:number):number{
  return a + (b - a) * t;
}

export function clipNum(v:number, min:number, max:number):number{
  return v > max ? max : (v < min ? min : v);
}

export function circularDelta(
  index: number,
  selectedIndex: number,
  length: number
): number {
  const half = Math.floor(length / 2)
  const raw = index - selectedIndex
  return ((raw + length + half) % length) - half
}