import { cn } from "@/lib/utils"

function Skeleton({
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn("animate-pulse rounded-md bg-neutral-200 dark:bg-neutral-800 m-2", className)}
      {...props}
    >{children || <br/>}</div>
  )
}

export { Skeleton }
