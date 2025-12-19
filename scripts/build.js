const fs = require('fs')
const path = require('path')
const stylus = require('stylus')
const autoprefixer = require('autoprefixer-stylus')
const pkg = require('../package.json')

const inputFile = path.join(__dirname, '../src/main.styl')
const outputFile = path.join(__dirname, '../dist/main.css')
const distDir = path.dirname(outputFile)
const pkgFile = path.join(__dirname, '../package.json')

// Bump version
const now = new Date()
const pad = (n) => n.toString().padStart(2, '0')
const version = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}.${pad(now.getHours())}.${pad(now.getMinutes())}`

// Only update version if userStyle object exists, otherwise just log or init it
if (!pkg.userStyle) {
  pkg.userStyle = {
    namespace: 'github.com/your-username/your-theme',
    version: version,
  }
} else {
  pkg.userStyle.version = version
}

fs.writeFileSync(pkgFile, JSON.stringify(pkg, null, 2) + '\n')
console.log(`Bumped version to ${version}`)

// Create dist dir if not exists
if (!fs.existsSync(distDir)) {
  fs.mkdirSync(distDir, { recursive: true })
}

// Generate UserStyle header
const header = `/* ==UserStyle==
@name         ${pkg.name}
@version      ${version}
@namespace    ${pkg.userStyle.namespace}
@description  ${pkg.description || 'No description provided.'}
@author       ${pkg.author || 'Unknown'}
@github       ${pkg.repository ? pkg.repository.url : ''}
@homepageURL  ${pkg.homepage || ''}
@license      ${pkg.license || 'UNLICENSED'}
==/UserStyle== */

`

if (!fs.existsSync(inputFile)) {
  console.error(`Error: Source file not found: ${inputFile}`)
  process.exit(1)
}

const stylContent = fs.readFileSync(inputFile, 'utf8')

console.log('Building CSS...')

stylus(stylContent)
  .set('filename', inputFile)
  .use(autoprefixer())
  .render((err, css) => {
    if (err) {
      console.error('Error building CSS:', err)
      process.exit(1)
    }

    const finalCss = header + css
    fs.writeFileSync(outputFile, finalCss)
    console.log(`Build complete: ${outputFile}`)
  })
