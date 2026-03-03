export interface DateItem {
  date: Date
  timestamp: number
  weekStr: string
  dayStr: string
}

export function copyDateItem(left:DateItem,right:DateItem){
  left.date = right.date;
  left.timestamp = right.timestamp;
  left.weekStr = right.weekStr;
  left.dayStr = right.dayStr;
}

export class SlidingDateModel {

  private dates: DateItem[] = []
  private weekMap = ["周日","周一","周二","周三","周四","周五","周六"]
  private visibleCount: number = 7
  private bufferCount: number = 1

  constructor(
    base?: number | Date,
  ) {
    const center = typeof base === 'number'
      ? new Date(base)
      : (base ?? new Date())

    center.setHours(0,0,0,0)

    const total = this.visibleCount + this.bufferCount * 2
    const half = Math.floor(total / 2)

    for (let i = -half; i <= half; i++) {
      this.dates.push(this.createItem(center, i))
    }
  }

  createItem(base: Date, offset: number): DateItem {
    const d = new Date(base.getTime())
    d.setDate(base.getDate() + offset)
    console.info(`createItem${base.getDate()}/${d.getDate()}`);
    return {
      date: d,
      timestamp: d.getTime(),
      weekStr: this.weekMap[d.getDay()],
      dayStr: d.getDate() < 10
        ? `0${d.getDate()}`
        : `${d.getDate()}`
    }
  }

  getList(): DateItem[] {
    return this.dates
  }

  // 向右滑动一步
  slideRight() {
    const last = this.dates[this.dates.length - 1]

    // 删除最左
    this.dates.shift()

    const base = new Date(last.timestamp)
    base.setDate(base.getDate() + 1)

    this.dates.push({
      date: base,
      timestamp: base.getTime(),
      weekStr: this.weekMap[base.getDay()],
      dayStr: base.getDate() < 10
        ? `0${base.getDate()}`
        : `${base.getDate()}`
    })
  }

  // 向左滑动一步
  slideLeft() {
    const first = this.dates[0]

    // 删除最右
    this.dates.pop()

    const base = new Date(first.timestamp)
    base.setDate(base.getDate() - 1)

    this.dates.unshift({
      date: base,
      timestamp: base.getTime(),
      weekStr: this.weekMap[base.getDay()],
      dayStr: base.getDate() < 10
        ? `0${base.getDate()}`
        : `${base.getDate()}`
    })
  }
}