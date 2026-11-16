#!/usr/bin/env node
/**
 * Emite um JWT RS256 de curta duracao para validacao isolada (D9.7).
 * Nao commitar chaves nem tokens gerados.
 */
import { createSign, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';

function parseArgs(argv) {
  const out = {
    privateKeyPath: '',
    issuer: 'tech-challenge-auth',
    audience: 'tech-challenge-api',
    subject: 'cliente-teste',
    expiresInSec: 300,
  };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--private-key' && argv[i + 1]) out.privateKeyPath = argv[++i];
    else if (a === '--issuer' && argv[i + 1]) out.issuer = argv[++i];
    else if (a === '--audience' && argv[i + 1]) out.audience = argv[++i];
    else if (a === '--sub' && argv[i + 1]) out.subject = argv[++i];
    else if (a === '--expires' && argv[i + 1]) out.expiresInSec = Number(argv[++i]);
    else if (a === '--help' || a === '-h') {
      console.log(`Uso: node scripts/token-teste.mjs --private-key <jwt-priv.pem> [opcoes]
  --issuer   (padrao: tech-challenge-auth)
  --audience (padrao: tech-challenge-api)
  --sub      (padrao: cliente-teste)
  --expires  segundos (padrao: 300)`);
      process.exit(0);
    }
  }
  if (!out.privateKeyPath) {
    console.error('Obrigatorio: --private-key <arquivo.pem>');
    process.exit(1);
  }
  return out;
}

function base64Url(buf) {
  return Buffer.from(buf)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function signJwtRs256(privateKeyPem, header, payload) {
  const encHeader = base64Url(JSON.stringify(header));
  const encPayload = base64Url(JSON.stringify(payload));
  const signingInput = `${encHeader}.${encPayload}`;
  const signer = createSign('RSA-SHA256');
  signer.update(signingInput);
  signer.end();
  const signature = signer.sign(privateKeyPem);
  return `${signingInput}.${base64Url(signature)}`;
}

const args = parseArgs(process.argv);
const privateKey = readFileSync(args.privateKeyPath, 'utf8');
const now = Math.floor(Date.now() / 1000);
const payload = {
  sub: args.subject,
  tipo: 'CLIENTE',
  perfil: 'CLIENTE',
  iss: args.issuer,
  aud: args.audience,
  iat: now,
  exp: now + args.expiresInSec,
  jti: randomUUID(),
};
const header = { alg: 'RS256', typ: 'JWT' };
const token = signJwtRs256(privateKey, header, payload);
console.log(token);