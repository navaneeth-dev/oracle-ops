// Tdarr "Custom JS Function" flow plugin: add a boosted stereo track.
// Output 1: a new file was written to the cache (the working file).
// Output 2: nothing to do; leave the file alone.
module.exports = async (args) => {
  const fs = require('fs');
  const path = require('path');
  const { spawn } = require('child_process');

  const file = args.inputFileObj._id;
  const probe = args.inputFileObj.ffProbeData || {};
  const streams = probe.streams || [];
  const tag = (s, k) => String((s.tags && (s.tags[k] || s.tags[k.toUpperCase()])) || '');
  const isEng = (s) => ['eng', 'en', 'english'].includes(tag(s, 'language').toLowerCase());
  const skip = (why) => {
    args.jobLog(`Skipping: ${why}`);
    return { outputFileObj: args.inputFileObj, outputNumber: 2, variables: args.variables };
  };

  if (path.extname(file).toLowerCase() !== '.mkv') return skip('not an mkv');
  const name = path.parse(file).name;
  if (/ - Stereo$/i.test(name)) return skip('this is a manual stereo copy');
  const manualCopy = fs.readdirSync(path.dirname(file)).find((f) => / - Stereo\.mkv$/i.test(f));
  if (manualCopy) return skip(`manual stereo copy exists: ${manualCopy}`);

  const audio = streams.filter((s) => s.codec_type === 'audio');
  const main = audio.filter((s) => !/commentary/i.test(tag(s, 'title')));
  if (main.length === 0) return skip('no non-commentary audio');
  const stereo = main.find((s) => Number(s.channels) > 0 && Number(s.channels) <= 2);
  if (stereo) return skip(`already has a stereo track (stream ${stereo.index})`);

  const isDefault = (s) => s.disposition && s.disposition.default === 1;
  const source = main.find((s) => isEng(s) && isDefault(s)) || main.find(isEng)
    || main.find(isDefault) || main[0];
  const language = tag(source, 'language') || 'eng';
  const subs = streams.filter((s) => s.codec_type === 'subtitle' && isEng(s));

  const out = path.join(args.workDir, path.basename(file));
  const ffArgs = [
    '-hide_banner', '-nostdin', '-y', '-i', file,
    '-map', '0:v', '-map', `0:${source.index}`,
    ...audio.flatMap((s) => ['-map', `0:${s.index}`]),
    ...subs.flatMap((s) => ['-map', `0:${s.index}`]),
    '-map', '0:t?',
    '-c', 'copy',
    '-c:a:0', 'aac', '-b:a:0', '192k', '-ac:a:0', '2', '-filter:a:0', 'volume=2',
    // The new track inherits the source track's tags (title, mkvmerge
    // statistics); blank them. -map_metadata would stop copying all streams' tags.
    ...Object.keys(source.tags || {}).flatMap((k) => ['-metadata:s:a:0', `${k}=`]),
    '-metadata:s:a:0', 'title=Stereo (boosted)', '-metadata:s:a:0', `language=${language}`,
    '-disposition:a:0', 'default',
    ...audio.flatMap((s, i) => [`-disposition:a:${i + 1}`, '0']),
    '-max_muxing_queue_size', '9999',
    out,
  ];
  args.jobLog(`Source audio: stream ${source.index} (${source.codec_name} ${source.channels}ch, ${language});`
    + ` keeping ${audio.length} original audio and ${subs.length} English subtitle streams`);
  args.jobLog(`${args.ffmpegPath} ${JSON.stringify(ffArgs)}`);

  const duration = Number((probe.format && probe.format.duration) || 0);
  const tail = [];
  const code = await new Promise((resolve, reject) => {
    const proc = spawn(args.ffmpegPath, ffArgs);
    proc.stderr.on('data', (d) => {
      const text = d.toString();
      tail.push(text);
      if (tail.length > 40) tail.shift();
      const m = text.match(/time=(\d+):(\d+):(\d+\.?\d*)/);
      if (m && duration > 0) {
        const t = Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3]);
        args.updateWorker({ percentage: Math.min(100, (t / duration) * 100) });
      }
    });
    proc.on('error', reject);
    proc.on('close', resolve);
  });
  if (code !== 0) {
    args.jobLog(tail.join(''));
    throw new Error(`ffmpeg exited with code ${code}`);
  }

  return { outputFileObj: { _id: out }, outputNumber: 1, variables: args.variables };
};
