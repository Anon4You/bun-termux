import _ from "lodash";

const msg = _.upperCase("bun is working on termux!");
console.log(msg);

const nums = [3, 1, 4, 1, 5, 9];
console.log("sorted:", _.sortBy(nums));
