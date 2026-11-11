'use client';
import {useEffect} from 'react';
import {mountHeader,mountTour,mountScroll,mountBackground,mountPinned,mountFounders} from './home-motion-runtime';
export function HeaderMotion(){useEffect(mountHeader,[]);return null;}
export function TourMotion(){useEffect(mountTour,[]);return null;}
export function ScrollMotion(){useEffect(mountScroll,[]);return null;}
export function BackgroundMotion({solutions=false}:{solutions?:boolean}={}){useEffect(()=>mountBackground(solutions?[["sm",.6,.4],["s-ins",.5,.5]]:undefined),[solutions]);return null;}
export function PinnedMotion(){useEffect(mountPinned,[]);return null;}
export function FoundersMotion(){useEffect(mountFounders,[]);return null;}
