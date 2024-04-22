import initSwc, { transformSync } from '@swc/wasm-web';
import { createElement } from 'react';

export const runFn = (src: string, args: [string, unknown][] = []) => {
  const result = transformSync(src, {
    filename: 'hello.tsx',
    jsc: {
      parser: {
        syntax: 'typescript',
        tsx: true,
      },
      transform: {
        react: {
          pragma: 'createElement',
        },
      },
    },
  });
  return Function(
    'createElement',
    ...args.map(([name]) => name),
    `return ${result.code}`
  )(createElement, ...args.map(([, val]) => val));
};

await initSwc();
