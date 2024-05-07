import {checkProgram} from './check';
import {parseProgram, tokenize} from './parse';
import {serializeProgram} from './serialize';
import * as fs from 'fs';

const [, , cmd, fileArg] = process.argv;
const file = process.cwd() + '/' + fileArg;

if (cmd === 'fmt') {
  const program = fs.readFileSync(file).toString();
  fs.writeFileSync(file, serializeProgram(parseProgram(tokenize(program))[0]));
} else if (cmd === 'check') {
  const program = fs.readFileSync(file).toString();
  const result = checkProgram(parseProgram(tokenize(program))[0]);
  if ('reason' in result) {
    console.log(result.reason);
  }
} else {
  console.log(`unknown command ${cmd}`);
}
