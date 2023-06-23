// SPDX-License-Identifier: MIT
pragma solidity =0.8.16;

import {Base64} from 'solady/src/utils/Base64.sol';
import {LibString} from 'solady/src/utils/LibString.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

/// @title ReceiptRenderer
/// @author RabbitHole.gg
/// @dev This contract is used to render on-chain data for RabbitHole Receipts (ERC-721 standard)
contract ReceiptRenderer {
    using LibString for uint256;
    string private constant GREEN_SVG = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="623" height="848"><defs><radialGradient id="A" cx="18.03" cy="-23.85" r="1" gradientTransform="matrix(-750 4.01 -3.89 -727.99 13738.75 -17063.51)" gradientUnits="userSpaceOnUse"><stop offset=".01" stop-color="#6aff67" stop-opacity=".39"/><stop offset=".14" stop-color="#59ff3e" stop-opacity=".22"/><stop offset=".3" stop-color="#4ad433" stop-opacity=".52"/><stop offset=".4" stop-color="#3eb42b" stop-opacity="0"/><stop offset="1" stop-opacity="0"/></radialGradient><radialGradient id="B" cx="17.91" cy="-23.86" r="1" gradientTransform="matrix(8,333,-579.59,13.92,-13669.05,-5581.04)" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#59ff3e" stop-opacity=".35"/><stop offset="1" stop-opacity="0"/></radialGradient><radialGradient xlink:href="#B" id="C" cx="18.09" cy="-23.91" gradientTransform="matrix(0,-345,877.77,0,21305.27,7045.5)"/><radialGradient xlink:href="#B" id="D" cx="17.93" cy="-23.91" gradientTransform="matrix(268,-2,8.57,1148.65,-4548.99,27879.6)"/><radialGradient id="E" cx="18.07" cy="-23.87" r="1" gradientTransform="matrix(-242,0,0,-1277.43,4934.5,-30115.86)" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#59ff3e" stop-opacity=".42"/><stop offset="1" stop-opacity="0"/></radialGradient><path id="F" d="M399.6 66H225.4A22 22 0 0 1 204 83h-39a22 22 0 0 1-21.4-17h-44L66 99.6V781h453.5l36.5-36.5v-641L518.5 66h-37.1A22 22 0 0 1 460 83h-39a22 22 0 0 1-21.4-17Z"/></defs><path d="M.5.5h622v847H.5z" stroke="#000" stroke-miterlimit="10"/><path d="M400.1 66.5H225.9a22 22 0 0 1-21.4 17h-39a22 22 0 0 1-21.4-17h-44l-33.6 33.6v681.4H520l36.5-36.5V104L519 66.5h-37.1a22 22 0 0 1-21.4 17h-39a22 22 0 0 1-21.4-17z" fill-opacity=".2"/><g transform="translate(.5 .5)"><use xlink:href="#F" fill="url(#A)"/><use xlink:href="#F" fill="url(#B)"/><use xlink:href="#F" fill="url(#C)"/><use xlink:href="#F" fill="url(#D)"/><use xlink:href="#F" fill="url(#E)"/></g><g fill="none" stroke="#42ff00" stroke-width="2"><path d="M204.5 84.5a23 23 0 0 0 22.2-17h172.6a23 23 0 0 0 22.2 17h39a23 23 0 0 0 22.2-17h35.9l36.9 36.9v640.2l-35.9 35.9H67.5v-680l33-33h42.8a23 23 0 0 0 22.2 17z" stroke-opacity=".97"/><path d="M312 305.3V68.5m-7.5 236.3V86.2L286 67.5m33.5 237.3V86.2L338 67.5M297.5 305V89.7l-22-22.2m52 237.3v-215l22-22.3M313 399.2v170.6m7.5-170.6v152.9l18.5 18.7m-33.5-171.6v152.9L287 570.8m40.5-171.3v149l22 22.2m-52-171.7v149.5l-22 22.2M209 602c0-17.397 14.103-31.5 31.5-31.5h140c17.397 0 31.5 14.103 31.5 31.5s-14.103 31.5-31.5 31.5h-140c-17.397 0-31.5-14.103-31.5-31.5zm276.3-260.7v12m0 0v12m0-12h-12m12 0h12m-12 7a7 7 0 1 1 0-14 7 7 0 1 1 0 14zm-353-19v12m0 0v12m0-12h-12m12 0h12m-12 7a7 7 0 1 1 0-14 7 7 0 1 1 0 14zm353 237v12m0 0v12m0-12h-12m12 0h12m-12 7a7 7 0 1 1 0-14 7 7 0 1 1 0 14zm-353-19v12m0 0v12m0-12h-12m12 0h12m-12 7a7 7 0 1 1 0-14 7 7 0 1 1 0 14z" stroke-opacity=".97"/></g><path d="M225.2 720.3v21h4.1v-9.1h3.6c1.2 0 1.9 1.3 1.9 4v5.1h3.8v-6.6c0-2.4-1-3.4-2.7-4 1.9-.8 2.6-2.5 2.6-4.6 0-4.1-1.4-5.8-4.7-5.8zm4.1 2.6h3.6c1.2 0 1.9 1.3 1.9 3.4s-.7 3.3-1.9 3.3h-3.6zm13.9-2.6v21h12.9v-2.6h-8.8V732h6.4v-2.5h-6.4v-6.6h8.8v-2.6zm17.5 0v21h9.4c2.4 0 4-2.5 4-5.7v-9.5c0-3.3-1.7-5.8-4-5.8zm4 2.6h3.7c1.1 0 1.8 1.5 1.8 3.2v9.5c0 1.6-.7 3.1-1.8 3.1h-3.7zm13.9-2.6v21h12.9v-2.6h-8.8V732h6.4v-2.5h-6.4v-6.6h8.8v-2.6zm17.7 0v21h12.9v-2.6h-8.8V732h6.4v-2.5h-6.4v-6.6h8.8v-2.6zm17.4 0v21h3.1v-13.2l2.1 13.2h3.1l2.3-13.3v13.3h2.9v-21h-4l-2.7 16-2.7-16zm27.5 21h4l-4.4-21h-5.3l-4.3 21h4.1l.6-4.4h4.6zm-3.2-18.4h.4l1.7 11.4h-3.8zm11-2.6v21h9.8c2.4 0 4-2.6 4-5.9s-.9-4.2-2.1-5c1.2-.9 1.7-2.3 1.7-4.3s-1.6-5.8-4-5.8zm4.1 2.6h3.6c1.2 0 1.9 1.2 1.9 3.3s-.7 3.1-1.9 3.1h-3.6zm0 9h4c1.1 0 1.8 1.5 1.8 3.4s-.7 3.4-1.8 3.4h-4zm13.8-11.6v21h13.4v-2.6H371v-18.4zm18 0v21h12.9v-2.6H389V732h6.4v-2.5H389v-6.6h8.8v-2.6z" fill="#f2f2f2"/><path d="M245.6 604.7v7.5H242v-20.1h8.3a8.67 8.67 0 0 1 5.4 1.6 6.11 6.11 0 0 1 1.8 4.7 5.7 5.7 0 0 1-4.1 5.7l4.9 8.1h-4l-4.4-7.5zm0-9.6v6.6h4.3a4.6 4.6 0 0 0 3.1-.8 3.59 3.59 0 0 0 0-5 4.6 4.6 0 0 0-3.1-.8zm26.6 17.1h-3.4c0-.4-.1-.8-.1-1.2a3.7 3.7 0 0 1-.1-1.1 3.89 3.89 0 0 1-1.7 1.9 6.12 6.12 0 0 1-2.9.7 4.51 4.51 0 0 1-3.3-1.2 3.5 3.5 0 0 1-1.3-3 3.7 3.7 0 0 1 1.2-2.9 6.65 6.65 0 0 1 3.8-1.4l4.1-.5v-.7a2.49 2.49 0 0 0-.7-1.9 2.72 2.72 0 0 0-1.9-.7 2.37 2.37 0 0 0-1.8.6 2.3 2.3 0 0 0-.8 1.6H260a4.49 4.49 0 0 1 1.8-3.5 6.35 6.35 0 0 1 4.2-1.3 6 6 0 0 1 4.4 1.4 5.29 5.29 0 0 1 1.5 4.1v7.5zm-9.4-4.1a1.7 1.7 0 0 0 .6 1.4 2.5 2.5 0 0 0 1.6.5 3.68 3.68 0 0 0 2.5-.9 3.22 3.22 0 0 0 1-2.5v-.8l-3.1.3a5.09 5.09 0 0 0-2 .7 1.49 1.49 0 0 0-.6 1.3zm20.2 4.4a5.21 5.21 0 0 1-2.7-.7 4.41 4.41 0 0 1-1.7-1.9v2.3h-3.4v-20.7h3.5v8.7a3.89 3.89 0 0 1 1.7-1.9 4.59 4.59 0 0 1 2.6-.7 5.61 5.61 0 0 1 4.4 2 9.42 9.42 0 0 1 0 10.8 5.4 5.4 0 0 1-4.4 2.1zm-1-12.3a3 3 0 0 0-2.5 1.2 5.68 5.68 0 0 0-.9 3.4v.5a5.92 5.92 0 0 0 .9 3.4 3 3 0 0 0 2.5 1.2 3.39 3.39 0 0 0 2.7-1.3 6.4 6.4 0 0 0 .9-3.6 6.08 6.08 0 0 0-.9-3.5 3.1 3.1 0 0 0-2.7-1.3zm17.4 12.3a5 5 0 0 1-2.7-.7 4.41 4.41 0 0 1-1.7-1.9v2.3h-3.4v-20.7h3.5v8.7a3.89 3.89 0 0 1 1.7-1.9 4.59 4.59 0 0 1 2.6-.7 5.61 5.61 0 0 1 4.4 2 9.42 9.42 0 0 1 0 10.8 5.4 5.4 0 0 1-4.4 2.1zm-1-12.3a3 3 0 0 0-2.5 1.2 5.68 5.68 0 0 0-.9 3.4v.5a5.92 5.92 0 0 0 .9 3.4 3 3 0 0 0 2.5 1.2 3.5 3.5 0 0 0 2.7-1.3 6.4 6.4 0 0 0 .9-3.6 6.08 6.08 0 0 0-.9-3.5 3.21 3.21 0 0 0-2.7-1.3zm13.2-4.7h-3.7V592h3.7zm-.2 16.7H308v-14.3h3.4zm9-2.7h.9l.9-.2v2.8l-1.4.3h-1.4a4.41 4.41 0 0 1-3.2-1 4.21 4.21 0 0 1-1.1-3.1v-7.8h-1.9v-2.6h1.9v-3.6h3.5v3.6h3.3v2.6h-3.3v7.2a2 2 0 0 0 .4 1.4 1.82 1.82 0 0 0 1.4.4zm7.9 2.7h-3.6v-20.1h3.6v8.4h10v-8.4h3.5v20.1h-3.5v-8.7h-10zm23.1-14.6a6.48 6.48 0 0 1 5 2 8.77 8.77 0 0 1 0 10.9 6.69 6.69 0 0 1-5 2 6.89 6.89 0 0 1-5.1-2 8.77 8.77 0 0 1 0-10.9 6.63 6.63 0 0 1 5.1-2zm0 2.6a3.22 3.22 0 0 0-2.6 1.3 5.77 5.77 0 0 0-.9 3.5 6.4 6.4 0 0 0 .9 3.6 3.1 3.1 0 0 0 2.6 1.2 2.9 2.9 0 0 0 2.5-1.2 5.68 5.68 0 0 0 1-3.6 5.4 5.4 0 0 0-1-3.5 3 3 0 0 0-2.5-1.3zm12.9-8.7v20.7h-3.5v-20.7zm12.5 16.2h3.2a5.19 5.19 0 0 1-2.2 3.5 6.07 6.07 0 0 1-4.1 1.3 6.88 6.88 0 0 1-5-2 8.77 8.77 0 0 1 0-10.9 6.69 6.69 0 0 1 5-2 5.49 5.49 0 0 1 4.6 2 7.29 7.29 0 0 1 1.7 5.2v1.1h-9.9a4.62 4.62 0 0 0 1.1 2.9 3.32 3.32 0 0 0 2.5 1.1 2.9 2.9 0 0 0 1.9-.6 3.41 3.41 0 0 0 1.2-1.6zm-3.1-7.5a3 3 0 0 0-2.3.9 4.55 4.55 0 0 0-1.2 2.5h6.5a3.61 3.61 0 0 0-.8-2.4 2.7 2.7 0 0 0-2.2-1zm121.1-431.6c12.565-4.904 20.136-17.775 18.317-31.14s-12.555-23.744-25.973-25.112-26.027 6.634-30.504 19.357.343 26.857 11.661 34.194a3.2 3.2 0 0 1 2.8-1.7c.2 0 .5-.3.4-.5a21.47 21.47 0 0 1-.7-5.1c0-10.7 8.1-19.3 18.1-19.3a1.92 1.92 0 0 0 1.6-1.1v-.2a2.6 2.6 0 0 0-1.6-3.3 18.91 18.91 0 0 1-13.7-14.1.81.81 0 0 1 1.4-.8l26.4 20.1a1.08 1.08 0 0 1 .4.9 18.25 18.25 0 0 0 .1 7.1.79.79 0 0 1-.3.9 8.1 8.1 0 0 1-8.6.5 1.38 1.38 0 0 0-1.1-.2 1.51 1.51 0 0 0-1.1 1.4v12.2a.9.9 0 0 1-.9.9h-1.6a.9.9 0 0 1-.9-.9 8.4 8.4 0 0 0-8.1-7.4h-.8a.6.6 0 1 0 .1 1.2 7.3 7.3 0 0 1 6 7.3 7.52 7.52 0 0 1-.2 1.5.9.9 0 0 0 .68 1.08h7.02a1.21 1.21 0 0 1 .5.5 2.58 2.58 0 0 1 .6 1.72zM467.4 137a.6.6 0 0 1 .4-1.1h16.6c.304-.138.662-.004.8.3s.004.662-.3.8a14.56 14.56 0 0 1-8.8 3.1 14 14 0 0 1-8.7-3.1zm31.5 5.3a1.6 1.6 0 0 1-3.197-.131 1.6 1.6 0 0 1 1.597-1.569 1.7 1.7 0 0 1 1.6 1.7z" fill="#dae0ff"/><text alignment-baseline="middle" text-anchor="middle" transform="translate(311 370.9)" font-size="44" fill="#fff" font-family="ArialMT, Arial">';
    string private constant PURPLE_SVG = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="623" height="848" xmlns:v="https://vecta.io/nano"><defs><radialGradient id="A" cx="18.03" cy="-23.85" r="1" gradientTransform="matrix(-778.44 0 0 -755.59 14341.92 -17655.24)" xlink:href="#G"><stop offset=".01" stop-color="#de80ff" stop-opacity=".39"/><stop offset=".14" stop-color="#ec7bff" stop-opacity=".22"/><stop offset=".27" stop-color="#f25aff" stop-opacity=".48"/><stop offset="1" stop-color="#1c231b" stop-opacity="0"/></radialGradient><radialGradient id="B" cx="17.91" cy="-23.86" r="1" gradientTransform="matrix(8,333,-579.59,13.92,-13669.05,-5581.04)" xlink:href="#G"><stop offset="0" stop-color="#8f00ff" stop-opacity=".51"/><stop offset="1" stop-color="#1c231b" stop-opacity="0"/></radialGradient><radialGradient id="C" cx="18.09" cy="-23.91" r="1" gradientTransform="matrix(0,-345,877.77,0,21305.27,7045.5)" xlink:href="#G"><stop offset="0" stop-color="#c13fff"/><stop offset="1" stop-color="#1c231b" stop-opacity="0"/></radialGradient><radialGradient id="D" cx="17.93" cy="-23.91" r="1" gradientTransform="matrix(268,-2,8.57,1148.65,-4548.99,27879.6)" xlink:href="#G"><stop offset="0" stop-color="#b946ff"/><stop offset="1" stop-color="#1c231b" stop-opacity="0"/></radialGradient><radialGradient id="E" cx="18.07" cy="-23.87" r="1" gradientTransform="matrix(-242,0,0,-1277.43,4934.5,-30115.86)" xlink:href="#G"><stop offset="0" stop-color="#dd0fff" stop-opacity=".91"/><stop offset="1" stop-color="#1c231b" stop-opacity="0"/></radialGradient><path id="F" d="M399.6 66H225.4A22 22 0 0 1 204 83h-39a22 22 0 0 1-21.4-17h-44L66 99.6V781h453.5l36.5-36.5v-641L518.5 66h-37.1A22 22 0 0 1 460 83h-39a22 22 0 0 1-21.4-17Z"/><linearGradient id="G" gradientUnits="userSpaceOnUse"/></defs><path d="M.5.5h622v847H.5z" stroke="#000" stroke-miterlimit="10"/><g fill-rule="evenodd"><path d="M400 66.5H225.8a22 22 0 0 1-21.4 17h-39a22 22 0 0 1-21.4-17h-44l-33.6 33.6v681.4h453.5l36.5-36.5V104l-37.5-37.5h-37.1a22 22 0 0 1-21.4 17h-39a22 22 0 0 1-21.4-17z" fill="#0c0b0f" fill-opacity=".26"/><g transform="translate(.4 .5)"><use xlink:href="#F" fill-opacity=".99" fill="url(#A)"/><use xlink:href="#F" fill-opacity=".5" fill="url(#B)"/><use xlink:href="#F" fill-opacity=".5" fill="url(#C)"/><use xlink:href="#F" fill-opacity=".5" fill="url(#D)"/><use xlink:href="#F" fill-opacity=".5" fill="url(#E)"/></g></g><g fill="none" stroke="#ad86ff" stroke-width="2"><path d="M204.4 84.5a23 23 0 0 0 22.2-17h172.6a23 23 0 0 0 22.2 17h39a23 23 0 0 0 22.2-17h35.9l36.9 36.9v640.2l-35.9 35.9H67.4v-680l33-33h42.8a23 23 0 0 0 22.2 17z"/><path d="M311.9 305.3V68.5m-7.5 236.3V86.2l-18.5-18.7m33.5 237.3V86.2l18.5-18.7M297.4 305V89.7l-22-22.2m52 237.3v-215l22-22.3m-36.5 331.7v170.6m7.5-170.6v152.9l18.5 18.7m-33.5-171.6v152.9l-18.5 18.7m40.5-171.3v149l22 22.2m-52-171.7v149.5l-22 22.2M208.9 602c0-17.397 14.103-31.5 31.5-31.5h140c17.397 0 31.5 14.103 31.5 31.5s-14.103 31.5-31.5 31.5h-140c-17.397 0-31.5-14.103-31.5-31.5zm276.8-260.7v12m0 0v12m0-12h-12m12 0h12m-12 7a7 7 0 1 1 0-14 7 7 0 1 1 0 14zm-353-19v12m0 0v12m0-12h-12m12 0h12m-12 7a7 7 0 1 1 0-14 7 7 0 1 1 0 14zm353 237v12m0 0v12m0-12h-12m12 0h12m-12 7a7 7 0 1 1 0-14 7 7 0 1 1 0 14zm-353-19v12m0 0v12m0-12h-12m12 0h12m-12 7a7 7 0 1 1 0-14 7 7 0 1 1 0 14z"/></g><path d="M242.7 714.5v21h4v-9.1h3.6c1.3 0 1.9 1.3 1.9 4v5.1h3.9v-6.6a3.7 3.7 0 0 0-2.8-4c2-.8 2.7-2.5 2.7-4.6 0-4.1-1.5-5.8-4.7-5.8zm4 2.6h3.7c1.2 0 1.9 1.3 1.9 3.4s-.7 3.3-1.9 3.3h-3.7zm14-2.6v21h12.8v-2.6h-8.7v-6.7h6.4v-2.5h-6.4v-6.6h8.7v-2.6zm17.4 0v21h9.5c2.4 0 3.9-2.5 3.9-5.7v-9.5c0-3.3-1.6-5.8-3.9-5.8zm4.1 2.6h3.7c1.1 0 1.8 1.5 1.8 3.2v9.5c0 1.6-.7 3.1-1.8 3.1h-3.7zm13.9-2.6v21H309v-2.6h-8.8v-6.7h6.4v-2.5h-6.4v-6.6h8.8v-2.6zm17.7 0v21h12.9v-2.6h-8.8v-6.7h6.4v-2.5h-6.4v-6.6h8.8v-2.6zm17.4 0v21h3v-13.2l2.1 13.2h3.2l2.3-13.3v13.3h2.9v-21h-4l-2.7 16-2.8-16zm18 0v21h12.9v-2.6h-8.8v-6.7h6.4v-2.5h-6.4v-6.6h8.8v-2.6zm17.5 0v21h9.4c2.4 0 4-2.5 4-5.7v-9.5c0-3.3-1.6-5.8-4-5.8zm4 2.6h3.7c1.2 0 1.9 1.5 1.9 3.2v9.5c0 1.6-.7 3.1-1.9 3.1h-3.7zM245.5 604.7v7.5h-3.6v-20.1h8.3a8.67 8.67 0 0 1 5.4 1.6 6.11 6.11 0 0 1 1.8 4.7 5.7 5.7 0 0 1-4.1 5.7l4.9 8.1h-4l-4.4-7.5zm0-9.6v6.6h4.3a4.6 4.6 0 0 0 3.1-.8 3.59 3.59 0 0 0 0-5 4.6 4.6 0 0 0-3.1-.8zm26.6 17.1h-3.4c0-.4-.1-.8-.1-1.2a3.7 3.7 0 0 1-.1-1.1 3.89 3.89 0 0 1-1.7 1.9 6.12 6.12 0 0 1-2.9.7 4.51 4.51 0 0 1-3.3-1.2 3.5 3.5 0 0 1-1.3-3 3.7 3.7 0 0 1 1.2-2.9 6.65 6.65 0 0 1 3.8-1.4l4.1-.5v-.7a2.49 2.49 0 0 0-.7-1.9 2.72 2.72 0 0 0-1.9-.7 2.37 2.37 0 0 0-1.8.6 2.3 2.3 0 0 0-.8 1.6h-3.3a4.49 4.49 0 0 1 1.8-3.5 6.35 6.35 0 0 1 4.2-1.3 6 6 0 0 1 4.4 1.4 5.29 5.29 0 0 1 1.5 4.1v7.5zm-9.4-4.1a1.7 1.7 0 0 0 .6 1.4 2.5 2.5 0 0 0 1.6.5 3.68 3.68 0 0 0 2.5-.9 3.22 3.22 0 0 0 1-2.5v-.8l-3.1.3a5.09 5.09 0 0 0-2 .7 1.49 1.49 0 0 0-.6 1.3zm20.2 4.4a5.21 5.21 0 0 1-2.7-.7 4.41 4.41 0 0 1-1.7-1.9v2.3h-3.4v-20.7h3.5v8.7a3.89 3.89 0 0 1 1.7-1.9 4.59 4.59 0 0 1 2.6-.7 5.61 5.61 0 0 1 4.4 2 9.42 9.42 0 0 1 0 10.8 5.4 5.4 0 0 1-4.4 2.1zm-1-12.3a3 3 0 0 0-2.5 1.2 5.68 5.68 0 0 0-.9 3.4v.5a5.92 5.92 0 0 0 .9 3.4 3 3 0 0 0 2.5 1.2 3.39 3.39 0 0 0 2.7-1.3 6.4 6.4 0 0 0 .9-3.6 6.08 6.08 0 0 0-.9-3.5 3.1 3.1 0 0 0-2.7-1.3zm17.4 12.3a5 5 0 0 1-2.7-.7 4.41 4.41 0 0 1-1.7-1.9v2.3h-3.4v-20.7h3.5v8.7a3.89 3.89 0 0 1 1.7-1.9 4.59 4.59 0 0 1 2.6-.7 5.61 5.61 0 0 1 4.4 2 9.42 9.42 0 0 1 0 10.8 5.4 5.4 0 0 1-4.4 2.1zm-1-12.3a3 3 0 0 0-2.5 1.2 5.68 5.68 0 0 0-.9 3.4v.5a5.92 5.92 0 0 0 .9 3.4 3 3 0 0 0 2.5 1.2 3.5 3.5 0 0 0 2.7-1.3 6.4 6.4 0 0 0 .9-3.6 6.08 6.08 0 0 0-.9-3.5 3.21 3.21 0 0 0-2.7-1.3zm13.2-4.7h-3.7V592h3.7zm-.2 16.7h-3.4v-14.3h3.4zm9-2.7h.9l.9-.2v2.8l-1.4.3h-1.4a4.41 4.41 0 0 1-3.2-1 4.21 4.21 0 0 1-1.1-3.1v-7.8h-1.9v-2.6h1.9v-3.6h3.5v3.6h3.3v2.6h-3.3v7.2a2 2 0 0 0 .4 1.4 1.82 1.82 0 0 0 1.4.4zm7.9 2.7h-3.6v-20.1h3.6v8.4h10v-8.4h3.5v20.1h-3.5v-8.7h-10zm23.1-14.6a6.48 6.48 0 0 1 5 2 8.77 8.77 0 0 1 0 10.9 6.69 6.69 0 0 1-5 2 6.89 6.89 0 0 1-5.1-2 8.77 8.77 0 0 1 0-10.9 6.63 6.63 0 0 1 5.1-2zm0 2.6a3.22 3.22 0 0 0-2.6 1.3 5.77 5.77 0 0 0-.9 3.5 6.4 6.4 0 0 0 .9 3.6 3.1 3.1 0 0 0 2.6 1.2 2.9 2.9 0 0 0 2.5-1.2 5.68 5.68 0 0 0 1-3.6 5.4 5.4 0 0 0-1-3.5 3 3 0 0 0-2.5-1.3zm12.9-8.7v20.7h-3.5v-20.7zm12.5 16.2h3.2a5.19 5.19 0 0 1-2.2 3.5 6.07 6.07 0 0 1-4.1 1.3 6.88 6.88 0 0 1-5-2 8.77 8.77 0 0 1 0-10.9 6.69 6.69 0 0 1 5-2 5.49 5.49 0 0 1 4.6 2 7.29 7.29 0 0 1 1.7 5.2v1.1H370a4.62 4.62 0 0 0 1.1 2.9 3.32 3.32 0 0 0 2.5 1.1 2.9 2.9 0 0 0 1.9-.6 3.41 3.41 0 0 0 1.2-1.6zm-3.1-7.5a3 3 0 0 0-2.3.9 4.55 4.55 0 0 0-1.2 2.5h6.5a3.61 3.61 0 0 0-.8-2.4 2.7 2.7 0 0 0-2.2-1zm121.1-431.6c12.565-4.904 20.136-17.775 18.317-31.14s-12.555-23.744-25.973-25.112-26.027 6.634-30.504 19.357.343 26.857 11.661 34.194a3.2 3.2 0 0 1 2.8-1.7c.2 0 .5-.3.4-.5a21.47 21.47 0 0 1-.7-5.1c0-10.7 8.1-19.3 18.1-19.3a1.92 1.92 0 0 0 1.6-1.1v-.2a2.6 2.6 0 0 0-1.6-3.3 18.91 18.91 0 0 1-13.7-14.1.81.81 0 0 1 1.4-.8l26.4 20.1a1.08 1.08 0 0 1 .4.9 18.25 18.25 0 0 0 .1 7.1.79.79 0 0 1-.3.9 8.1 8.1 0 0 1-8.6.5 1.38 1.38 0 0 0-1.1-.2 1.51 1.51 0 0 0-1.1 1.4v12.2a.9.9 0 0 1-.9.9h-1.6a.9.9 0 0 1-.9-.9 8.4 8.4 0 0 0-8.1-7.4h-.8a.6.6 0 1 0 .1 1.2 7.3 7.3 0 0 1 6 7.3 7.52 7.52 0 0 1-.2 1.5.9.9 0 0 0 .68 1.08h7.02a1.21 1.21 0 0 1 .5.5 2.58 2.58 0 0 1 .6 1.72zM467.3 137a.6.6 0 0 1 .4-1.1h16.6c.304-.138.662-.004.8.3s.004.662-.3.8a14.56 14.56 0 0 1-8.8 3.1 14 14 0 0 1-8.7-3.1zm31.5 5.3a1.6 1.6 0 0 1-3.197-.131 1.6 1.6 0 0 1 1.597-1.569 1.7 1.7 0 0 1 1.6 1.7z" fill="#dae0ff"/><text alignment-baseline="middle" text-anchor="middle" transform="translate(311 370.9)" font-size="44" fill="#fff" font-family="ArialMT, Arial">';

    /// @dev generates the tokenURI for a given ERC-721 token ID
    /// @param tokenId_ The token id to generate the URI for
    /// @param questId_ The questId tied to the tokenId
    /// @param totalParticipants_ The total number of participants in the quest
    /// @param claimed_ Whether or not the token has been claimed
    /// @param rewardAmount_ The amount of reward tokens that the user is eligible for
    /// @param rewardAddress_ The address of the reward token
    /// @return encoded JSON following the generic OpenSea metadata standard
    function generateTokenURI(
        uint tokenId_,
        string memory questId_,
        uint totalParticipants_,
        bool claimed_,
        uint rewardAmount_,
        address rewardAddress_
    ) external view virtual returns (string memory) {
        bytes memory dataURI = generateDataURI(
            tokenId_,
            questId_,
            totalParticipants_,
            claimed_,
            rewardAmount_,
            rewardAddress_
        );
        return string(abi.encodePacked('data:application/json;base64,', Base64.encode(dataURI)));
    }

    function generateDataURI(
        uint tokenId_,
        string memory questId_,
        uint totalParticipants_,
        bool claimed_,
        uint rewardAmount_,
        address rewardAddress_
    ) internal view virtual returns (bytes memory) {
        string memory tokenIdString = tokenId_.toString();
        string memory humanRewardAmountString = this.humanRewardAmount(rewardAmount_, rewardAddress_);
        string memory rewardTokenSymbol = this.symbolForAddress(rewardAddress_);

        bytes memory attributes = abi.encodePacked(
            '[',
            generateAttribute('Quest ID', questId_),
            ',',
            generateAttribute('Token ID', tokenIdString),
            ',',
            generateAttribute('Total Participants', totalParticipants_.toString()),
            ',',
            generateAttribute('Claimed', claimed_ ? 'true' : 'false'),
            ',',
            generateAttribute('Reward Amount', humanRewardAmountString),
            ',',
            generateAttribute('Reward Address', LibString.toHexString(uint160(rewardAddress_), 20)),
            ']'
        );
        bytes memory dataURI = abi.encodePacked(
            '{',
            '"name": "RabbitHole.gg Receipt #',
            tokenIdString,
            '",',
            '"description": "RabbitHole.gg Receipts are used to claim rewards from completed quests.",',
            '"image": "',
            generateSVG(claimed_, humanRewardAmountString, rewardTokenSymbol),
            '",',
            '"attributes": ',
            attributes,
            '}'
        );
        return dataURI;
    }

    /// @dev generates an attribute object for an ERC-721 token
    /// @param key The key for the attribute
    /// @param value The value for the attribute
    function generateAttribute(string memory key, string memory value) internal pure returns (string memory) {
        bytes memory attribute = abi.encodePacked(
            '{',
            '"trait_type": "',
            key,
            '",',
            '"value": "',
            value,
            '"',
            '}'
        );
        return string(attribute);
    }

    /// @dev generates the on-chain SVG for an ERC-721 token ID
    /// @param claimed_ Whether or not the token has been claimed
    /// @param rewardAmountString_ The string decimal of reward tokens that the user is eligible for
    /// @param rewardTokenSymbol_ The symbol of the reward token
    /// @return base64 encoded SVG image
    function generateSVG(bool claimed_, string memory rewardAmountString_, string memory rewardTokenSymbol_) internal pure returns (string memory) {
        bytes memory svg = abi.encodePacked(
            claimed_ ? PURPLE_SVG : GREEN_SVG,
            rewardAmountString_,
            ' ',
            rewardTokenSymbol_,
            '</text></svg>'
        );
        return string(abi.encodePacked('data:image/svg+xml;base64,', Base64.encode(svg)));
    }

    /// @dev Returns a human readable reward amount
    /// @param rewardAmount_ The reward amount
    /// @param rewardAddress_ The reward address
    function humanRewardAmount(uint rewardAmount_, address rewardAddress_) external view returns (string memory) {
        uint8 decimals;

        if (rewardAddress_ == address(0)) {
            decimals = 18;
        } else {
            decimals = ERC20(rewardAddress_).decimals();
        }

        return decimalString(rewardAmount_, decimals, false);
    }

    /// @dev Returns the symbol for a token address
    /// @param tokenAddress_ The reward address
    function symbolForAddress(address tokenAddress_) external view returns (string memory) {
        string memory symbol;

        if (tokenAddress_ == address(0)) {
            symbol = 'ETH';
        } else {
            symbol = ERC20(tokenAddress_).symbol();
        }

        return symbol;
    }

    /// @notice From https://gist.github.com/wilsoncusack/d2e680e0f961e36393d1bf0b6faafba7
    struct DecimalStringParams {
        // significant figures of decimal
        uint256 sigfigs;
        // length of decimal string
        uint8 bufferLength;
        // ending index for significant figures (funtion works backwards when copying sigfigs)
        uint8 sigfigIndex;
        // index of decimal place (0 if no decimal)
        uint8 decimalIndex;
        // start index for trailing/leading 0's for very small/large numbers
        uint8 zerosStartIndex;
        // end index for trailing/leading 0's for very small/large numbers
        uint8 zerosEndIndex;
        // true if decimal number is less than one
        bool isLessThanOne;
        // true if string should include "%"
        bool isPercent;
    }

    function decimalString(uint256 number, uint8 decimals, bool isPercent) internal pure returns (string memory){
        uint8 percentBufferOffset = isPercent ? 1 : 0;
        uint256 tenPowDecimals = 10 ** decimals;
        uint256 temp = number;
        uint8 digits;
        uint8 numSigfigs;
        while (temp != 0) {
            if (numSigfigs > 0) {
                // count all digits preceding least significant figure
                numSigfigs++;
            } else if (temp % 10 != 0) {
                numSigfigs++;
            }
            digits++;
            temp /= 10;
        }

        DecimalStringParams memory params;
        params.isPercent = isPercent;
        if ((digits - numSigfigs) >= decimals) {
            // no decimals, ensure we preserve all trailing zeros
            params.sigfigs = number / tenPowDecimals;
            params.sigfigIndex = digits - decimals;
            params.bufferLength = params.sigfigIndex + percentBufferOffset;
        } else {
            // chop all trailing zeros for numbers with decimals
            params.sigfigs = number / (10 ** (digits - numSigfigs));
            if (tenPowDecimals > number) {
                // number is less tahn one
                // in this case, there may be leading zeros after the decimal place
                // that need to be added

                // offset leading zeros by two to account for leading '0.'
                params.zerosStartIndex = 2;
                params.zerosEndIndex = decimals - digits + 2;
                params.sigfigIndex = numSigfigs + params.zerosEndIndex;
                params.bufferLength = params.sigfigIndex + percentBufferOffset;
                params.isLessThanOne = true;
            } else {
                // In this case, there are digits before and
                // after the decimal place
                params.sigfigIndex = numSigfigs + 1;
                params.decimalIndex = digits - decimals + 1;
            }
        }
        params.bufferLength = params.sigfigIndex + percentBufferOffset;
        return generateDecimalString(params);
    }

    function generateDecimalString(DecimalStringParams memory params) private pure returns (string memory) {
        bytes memory buffer = new bytes(params.bufferLength);
        if (params.isPercent) {
            buffer[buffer.length - 1] = '%';
        }
        if (params.isLessThanOne) {
            buffer[0] = '0';
            buffer[1] = '.';
        }

        // add leading/trailing 0's
        for (uint256 zerosCursor = params.zerosStartIndex; zerosCursor < params.zerosEndIndex; zerosCursor++) {
            buffer[zerosCursor] = bytes1(uint8(48));
        }
        // add sigfigs
        while (params.sigfigs > 0) {
            if (params.decimalIndex > 0 && params.sigfigIndex == params.decimalIndex) {
                buffer[--params.sigfigIndex] = '.';
            }
            buffer[--params.sigfigIndex] = bytes1(uint8(uint256(48) + (params.sigfigs % 10)));
            params.sigfigs /= 10;
        }
        return string(buffer);
    }
}