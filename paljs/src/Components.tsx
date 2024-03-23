export const Box = ({
  children,
  ...style
}: React.PropsWithChildren<React.CSSProperties>) => (
  <div style={{ display: 'flex', ...style }}>{children}</div>
);

export const Row = (props: React.PropsWithChildren<React.CSSProperties>) => (
  <Box flexDirection="row" {...props} />
);

export const Column = (props: React.PropsWithChildren<React.CSSProperties>) => (
  <Box flexDirection="column" {...props} />
);
