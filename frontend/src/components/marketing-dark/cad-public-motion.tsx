"use client";
import {useEffect} from "react";
import {mountCadBackground,mountCadComparison,mountCadResults,mountCadPipeline,mountCadFiles,mountCadEvidence,mountCadPrivacy,mountCadFolder} from "./cad-public-runtime";
export function CadBackgroundMotion(){useEffect(mountCadBackground,[]);return null;}
export function CadComparisonMotion(){useEffect(mountCadComparison,[]);return null;}
export function CadResultsMotion(){useEffect(mountCadResults,[]);return null;}
export function CadPipelineMotion(){useEffect(mountCadPipeline,[]);return null;}
export function CadFilesMotion(){useEffect(mountCadFiles,[]);return null;}
export function CadEvidenceMotion(){useEffect(mountCadEvidence,[]);return null;}
export function CadPrivacyMotion(){useEffect(mountCadPrivacy,[]);return null;}
export function CadFolderMotion(){useEffect(mountCadFolder,[]);return null;}
